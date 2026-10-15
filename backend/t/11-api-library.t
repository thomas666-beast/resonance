use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app fresh_db seed_users seed_library login_as);

my $app = fresh_app();
my $t   = Test::Mojo->new($app);
fresh_db($app);
my $users = seed_users($app);
my $lib   = seed_library($app, $users);

my $token = login_as($t, 'alice');
my $auth  = { Authorization => "Bearer $token" };

# ── artists ──────────────────────────────────────────────

$t->get_ok('/api/artists' => $auth)
  ->status_is(200)
  ->json_is('/artists/0/name' => 'Boards of Canada')
  ->json_is('/artists/1/name' => 'Pink Floyd')
  ->json_is('/artists/2/name' => 'Radiohead');

my $pink_id = $lib->{artists}[0]{id};

$t->get_ok("/api/artists/$pink_id" => $auth)
  ->status_is(200)
  ->json_is('/artist/name' => 'Pink Floyd')
  ->json_is('/albums/0/title' => 'The Dark Side of the Moon')
  ->json_is('/albums/1/title' => 'Wish You Were Here');

$t->get_ok('/api/artists/999999' => $auth)->status_is(404);
$t->get_ok('/api/artists/abc'    => $auth)->status_is(400);

# ── albums ───────────────────────────────────────────────

$t->get_ok('/api/albums' => $auth)
  ->status_is(200)
  ->json_is('/albums/0/title' => 'Kid A');

my $album_id = $lib->{albums}[0]{id};

$t->get_ok("/api/albums/$album_id" => $auth)
  ->status_is(200)
  ->json_is('/album/title' => 'The Dark Side of the Moon')
  ->json_is('/tracks/0/title' => 'Track 1 on The Dark Side of the Moon')
  ->json_is('/tracks/2/title' => 'Track 3 on The Dark Side of the Moon');

# ── tracks ───────────────────────────────────────────────

my $track_id = $lib->{tracks}[0]{id};

$t->get_ok("/api/tracks/$track_id" => $auth)
  ->status_is(200)
  ->json_is('/track/title' => 'Track 1 on The Dark Side of the Moon')
  ->json_hasnt('/track/path');

# ── search ───────────────────────────────────────────────

$t->get_ok('/api/search?q=Dark' => $auth)
  ->status_is(200)
  ->json_has('/albums')
  ->json_has('/artists')
  ->json_has('/tracks');

$t->get_ok('/api/search?q=a' => $auth)->status_is(200);
$t->get_ok('/api/search?q=' => $auth)
  ->status_is(200)
  ->json_is('/artists' => [])
  ->json_is('/albums'  => [])
  ->json_is('/tracks'  => []);

# ── stream (needs a real file) ───────────────────────────

use TestHelper qw(make_audio_file cleanup_audio_file);

my $audio = make_audio_file();
if ($audio) {
    # Point the first track at a real file
    $app->pg->db->query(
        'UPDATE tracks SET path = ? WHERE id = ?',
        $audio, $track_id,
    );

    $t->get_ok("/api/stream/$track_id" => $auth)
      ->status_is(200)
      ->header_is('Accept-Ranges' => 'bytes');

    # Range request
    $t->get_ok("/api/stream/$track_id" => {
        %$auth,
        Range => 'bytes=0-99',
    })->status_is(206)
      ->header_like('Content-Range' => qr{^bytes 0-99/\d+$});

    cleanup_audio_file($audio);
} else {
    diag "Skipping stream test — ffmpeg not available";
}

# Unknown track
$t->get_ok('/api/stream/999999' => $auth)->status_is(404);

# ── auth required ────────────────────────────────────────

$t->get_ok('/api/artists')->status_is(401);
$t->get_ok('/api/albums')->status_is(401);

done_testing;
