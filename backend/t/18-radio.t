use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app fresh_db seed_users login_as);

my $app = fresh_app();
my $t   = Test::Mojo->new($app);
fresh_db($app);
my $users = seed_users($app);

# ── admin can CRUD ───────────────────────────────────────

my $admin_token = login_as($t, 'admin');
my $admin_auth  = { Authorization => "Bearer $admin_token" };

# Empty list
$t->get_ok('/api/radio' => $admin_auth)
  ->status_is(200)
  ->json_is('/stations' => [])
  ->json_is('/is_admin' => 1);

# Create
$t->post_ok('/api/radio' => $admin_auth => json => {
    name       => 'SomaFM Groove Salad',
    stream_url => 'https://ice2.somafm.com/groovesalad-128-mp3',
    genre      => 'Ambient',
    bitrate    => 128,
})->status_is(201)
  ->json_is('/station/name' => 'SomaFM Groove Salad')
  ->json_is('/station/genre' => 'Ambient');

my $id = $t->tx->res->json->{station}{id};

# Missing fields
$t->post_ok('/api/radio' => $admin_auth => json => { name => 'X' })
  ->status_is(400)->json_is('/error' => 'stream_url_required');

# Bad URL
$t->post_ok('/api/radio' => $admin_auth => json => {
    name       => 'X',
    stream_url => 'ftp://example.com/stream',
})->status_is(400)->json_is('/error' => 'invalid_stream_url');

# Show
$t->get_ok("/api/radio/$id" => $admin_auth)
  ->status_is(200)
  ->json_is('/station/name' => 'SomaFM Groove Salad');

# Update
$t->patch_ok("/api/radio/$id" => $admin_auth => json => { genre => 'Chillout' })
  ->status_is(200)
  ->json_is('/station/genre' => 'Chillout');

# Delete
$t->delete_ok("/api/radio/$id" => $admin_auth)
  ->status_is(200);

$t->get_ok("/api/radio/$id" => $admin_auth)->status_is(404);

# ── regular user is denied ───────────────────────────────

my $user_token = login_as($t, 'alice');
my $user_auth  = { Authorization => "Bearer $user_token" };

$t->post_ok('/api/radio' => $user_auth => json => {
    name       => 'X',
    stream_url => 'http://example.com/x',
})->status_is(403)->json_is('/error' => 'admin_required');

$t->patch_ok('/api/radio/1' => $user_auth => json => { genre => 'X' })
  ->status_is(403);

$t->delete_ok('/api/radio/1' => $user_auth)
  ->status_is(403);

# Can still list
$t->get_ok('/api/radio' => $user_auth)
  ->status_is(200)
  ->json_is('/is_admin' => 0);

# ── private stations hidden from non-admins ──────────────

$t->post_ok('/api/radio' => $admin_auth => json => {
    name       => 'Private Station',
    stream_url => 'http://example.com/private',
    is_public  => 0,
})->status_is(201);

my $private_id = $t->tx->res->json->{station}{id};

# Admin sees it
$t->get_ok('/api/radio' => $admin_auth)
  ->json_is('/stations/0/name' => 'Private Station');

# Regular user doesn't
$t->get_ok('/api/radio' => $user_auth)
  ->json_is('/stations' => []);

$t->get_ok("/api/radio/$private_id" => $user_auth)->status_is(404);

# ── unauthenticated ──────────────────────────────────────

$t->get_ok('/api/radio')->status_is(401);

done_testing;
