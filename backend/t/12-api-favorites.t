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

my $track_id = $lib->{tracks}[0]{id};

# Initially empty
$t->get_ok('/api/favorites/ids' => $auth)
  ->status_is(200)
  ->json_is('/track_ids' => []);

# Add
$t->post_ok("/api/favorites/$track_id" => $auth)
  ->status_is(200)
  ->json_is('/favorited' => 1);

# Idempotent
$t->post_ok("/api/favorites/$track_id" => $auth)->status_is(200);

$t->get_ok('/api/favorites/ids' => $auth)
  ->status_is(200)
  ->json_is('/track_ids/0' => $track_id);

$t->get_ok('/api/favorites' => $auth)
  ->status_is(200)
  ->json_is('/tracks/0/id' => $track_id);

# Remove
$t->delete_ok("/api/favorites/$track_id" => $auth)
  ->status_is(200)
  ->json_is('/favorited' => 0);

$t->get_ok('/api/favorites/ids' => $auth)
  ->json_is('/track_ids' => []);

# Remove idempotent
$t->delete_ok("/api/favorites/$track_id" => $auth)->status_is(200);

# Unknown track
$t->post_ok('/api/favorites/999999' => $auth)
  ->status_is(404)
  ->json_is('/error' => 'track_not_found');

# Invalid id
$t->post_ok('/api/favorites/abc' => $auth)->status_is(400);

done_testing;
