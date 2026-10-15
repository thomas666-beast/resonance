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
seed_library($app, $users);

# ── regular user is denied ───────────────────────────────

my $user_token = login_as($t, 'alice');
my $user_auth  = { Authorization => "Bearer $user_token" };

$t->get_ok('/api/admin/users' => $user_auth)->status_is(403);
$t->get_ok('/api/admin/stats' => $user_auth)->status_is(403);
$t->post_ok('/api/admin/users' => $user_auth => json => {})
  ->status_is(403);

# ── admin works ──────────────────────────────────────────

my $admin_token = login_as($t, 'admin');
my $admin_auth  = { Authorization => "Bearer $admin_token" };

$t->get_ok('/api/admin/users' => $admin_auth)
  ->status_is(200)
  ->json_has('/users')
  ->json_is('/total' => 2);

$t->get_ok('/api/admin/stats' => $admin_auth)
  ->status_is(200)
  ->json_is('/counts/users' => 2)
  ->json_is('/counts/tracks' => 15);

# ── create user ──────────────────────────────────────────

$t->post_ok('/api/admin/users' => $admin_auth
    => json => { username => 'newbie', password => 'verysecret1' })
  ->status_is(201)
  ->json_is('/user/username' => 'newbie')
  ->json_is('/user/role'     => 'user');

my $newbie_id = $t->tx->res->json->{user}{id};

# Duplicate
$t->post_ok('/api/admin/users' => $admin_auth
    => json => { username => 'newbie', password => 'verysecret1' })
  ->status_is(409);

# ── update ───────────────────────────────────────────────

$t->patch_ok("/api/admin/users/$newbie_id" => $admin_auth
    => json => { role => 'admin' })
  ->status_is(200)
  ->json_is('/user/role' => 'admin');

$t->patch_ok("/api/admin/users/$newbie_id" => $admin_auth
    => json => { is_active => 0 })
  ->status_is(200)
  ->json_is('/user/is_active' => 0);

# ── self-protection ──────────────────────────────────────

my $admin_id = $users->{admin}{id};

$t->patch_ok("/api/admin/users/$admin_id" => $admin_auth
    => json => { role => 'user' })
  ->status_is(400)->json_is('/error' => 'cannot_demote_self');

$t->delete_ok("/api/admin/users/$admin_id" => $admin_auth)
  ->status_is(400)->json_is('/error' => 'cannot_delete_self');

# ── search and sort ──────────────────────────────────────

$t->get_ok('/api/admin/users?q=ali' => $admin_auth)
  ->status_is(200)->json_is('/users/0/username' => 'alice');

$t->get_ok('/api/admin/users?sort=username&dir=asc' => $admin_auth)
  ->status_is(200)
  ->json_is('/users/0/username' => 'admin')
  ->json_is('/users/1/username' => 'alice');

# ── delete ───────────────────────────────────────────────

$t->delete_ok("/api/admin/users/$newbie_id" => $admin_auth)
  ->status_is(200);
$t->get_ok("/api/admin/users?q=newbie" => $admin_auth)
  ->json_is('/total' => 0);

done_testing;
