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

# ── list ─────────────────────────────────────────────────

$t->get_ok('/api/playlists' => $auth)
  ->status_is(200)
  ->json_is('/playlists/0/name' => 'Test Playlist')
  ->json_is('/playlists/0/track_count' => 3);

# ── create ───────────────────────────────────────────────

$t->post_ok('/api/playlists' => $auth
    => json => { name => 'New List', description => 'cool' })
  ->status_is(201)
  ->json_is('/playlist/name' => 'New List');

my $new_id = $t->tx->res->json->{playlist}{id};

$t->post_ok('/api/playlists' => $auth => json => {})
  ->status_is(400)->json_is('/error' => 'name_required');

# ── show ─────────────────────────────────────────────────

$t->get_ok("/api/playlists/$new_id" => $auth)
  ->status_is(200)
  ->json_is('/playlist/name' => 'New List')
  ->json_is('/tracks' => []);

# ── add tracks ───────────────────────────────────────────

my @ids = map { $_->{id} } @{ $lib->{tracks} }[0 .. 3];

for my $i (0 .. $#ids) {
    $t->post_ok("/api/playlists/$new_id/tracks" => $auth
        => json => { track_id => $ids[$i] })
      ->status_is(200);
}

$t->get_ok("/api/playlists/$new_id" => $auth)
  ->json_is('/tracks/0/id' => $ids[0])
  ->json_is('/tracks/3/id' => $ids[3]);

# Duplicate add ignored
$t->post_ok("/api/playlists/$new_id/tracks" => $auth
    => json => { track_id => $ids[0] })->status_is(200);

$t->get_ok("/api/playlists/$new_id" => $auth)->status_is(200);
is scalar @{ $t->tx->res->json->{tracks} }, 4, 'still 4 tracks after duplicate add';

# ── reorder ──────────────────────────────────────────────

my @reversed = reverse @ids;
$t->patch_ok("/api/playlists/$new_id/reorder" => $auth
    => json => { track_ids => \@reversed })
  ->status_is(200);

$t->get_ok("/api/playlists/$new_id" => $auth)
  ->json_is('/tracks/0/id' => $reversed[0])
  ->json_is('/tracks/3/id' => $reversed[3]);

# ── remove track ─────────────────────────────────────────

$t->delete_ok("/api/playlists/$new_id/tracks/$reversed[0]" => $auth)
  ->status_is(200);

$t->get_ok("/api/playlists/$new_id" => $auth)->status_is(200);
is scalar @{ $t->tx->res->json->{tracks} }, 3, 'still 3 tracks after removal';

# ── update ───────────────────────────────────────────────

$t->patch_ok("/api/playlists/$new_id" => $auth
    => json => { name => 'Renamed', is_public => 1 })
  ->status_is(200)
  ->json_is('/playlist/name' => 'Renamed')
  ->json_is('/playlist/is_public' => 1);

# ── ownership ────────────────────────────────────────────

my $bob_token = login_as($t, 'admin');
my $bob_auth  = { Authorization => "Bearer $bob_token" };

# Admin can't edit alice's private playlist (owner-only for writes)
$t->patch_ok("/api/playlists/$new_id" => $bob_auth
    => json => { name => 'Hacked' })
  ->status_is(404);

# ── delete ───────────────────────────────────────────────

$t->delete_ok("/api/playlists/$new_id" => $auth)->status_is(200);
$t->get_ok("/api/playlists/$new_id" => $auth)->status_is(404);

done_testing;
