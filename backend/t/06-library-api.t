use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";

local $ENV{JWT_SECRET}         = 'a' x 32;
local $ENV{ALLOW_REGISTRATION} = 1;
local $ENV{POSTGRES_HOST}      = $ENV{POSTGRES_HOST}     // '127.0.0.1';
local $ENV{POSTGRES_PORT}      = $ENV{POSTGRES_PORT}     // 5432;
local $ENV{POSTGRES_DB}        = $ENV{POSTGRES_DB}       // 'resonance_test';
local $ENV{POSTGRES_USER}      = $ENV{POSTGRES_USER}     // 'resonance';
local $ENV{POSTGRES_PASSWORD}  = $ENV{POSTGRES_PASSWORD} // 'change-me';
local $ENV{REDIS_URL}          = $ENV{REDIS_URL}         // 'redis://127.0.0.1:6379/0';

require Resonance;

my $app = Resonance->new;
my $t   = Test::Mojo->new($app);

$app->pg->db->query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
$app->pg->migrations->from_dir('migrations')->migrate;
$app->minion->backend->pg->migrations->name('minion')->migrate;

# Seed data
my $db = $app->pg->db;
my $artist = $db->query("INSERT INTO artists (name) VALUES ('Test Artist') RETURNING id")->hash;
my $album  = $db->query(
    "INSERT INTO albums (title, artist_id, year) VALUES ('Test Album', ?, 2020) RETURNING id",
    $artist->{id},
)->hash;
my $track = $db->query(
    "INSERT INTO tracks (title, album_id, artist_id, track_number, duration_ms, path, mime_type)
     VALUES ('Test Track', ?, ?, 1, 180000, '/tmp/does-not-exist.mp3', 'audio/mpeg') RETURNING id",
    $album->{id}, $artist->{id},
)->hash;

# Auth
$t->post_ok('/api/auth/register' => json => {
    username => 'lib_' . int(rand(1_000_000)),
    password => 'correct-horse-battery',
})->status_is(200);
my $access = $t->tx->res->json->{access_token};

# Artists
$t->get_ok('/api/artists' => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/artists/0/name' => 'Test Artist');

# Artist detail
$t->get_ok("/api/artists/$artist->{id}" => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/artist/name' => 'Test Artist')
  ->json_is('/albums/0/title' => 'Test Album');

# Albums
$t->get_ok('/api/albums' => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/albums/0/title' => 'Test Album');

# Album detail
$t->get_ok("/api/albums/$album->{id}" => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/album/title' => 'Test Album')
  ->json_is('/tracks/0/title' => 'Test Track');

# Track detail
$t->get_ok("/api/tracks/$track->{id}" => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/track/title' => 'Test Track')
  ->json_is('/track/duration_ms' => 180000)
  ->json_hasnt('/track/path');   # path must not leak

# 404s
$t->get_ok('/api/artists/999999' => { Authorization => "Bearer $access" })
  ->status_is(404);
$t->get_ok('/api/albums/999999' => { Authorization => "Bearer $access" })
  ->status_is(404);
$t->get_ok('/api/tracks/999999' => { Authorization => "Bearer $access" })
  ->status_is(404);

# Invalid ids
$t->get_ok('/api/artists/abc' => { Authorization => "Bearer $access" })
  ->status_is(400);

# Stream — missing file
$t->get_ok("/api/stream/$track->{id}" => { Authorization => "Bearer $access" })
  ->status_is(404)
  ->json_is('/error' => 'file_missing');

# Unauthenticated
$t->get_ok('/api/artists')->status_is(401);

done_testing;
