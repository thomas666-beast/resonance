use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";

# Set env for test
local $ENV{JWT_SECRET}            = 'a' x 32;
local $ENV{ALLOW_REGISTRATION}    = 1;
local $ENV{POSTGRES_HOST}         = $ENV{POSTGRES_HOST} // '127.0.0.1';
local $ENV{POSTGRES_PORT}         = $ENV{POSTGRES_PORT} // 5432;
local $ENV{POSTGRES_DB}           = $ENV{POSTGRES_DB}   // 'resonance_test';
local $ENV{POSTGRES_USER}         = $ENV{POSTGRES_USER} // 'resonance';
local $ENV{POSTGRES_PASSWORD}     = $ENV{POSTGRES_PASSWORD} // 'change-me';
local $ENV{REDIS_URL}             = $ENV{REDIS_URL} // 'redis://127.0.0.1:6379/0';

require Resonance;

my $app = Resonance->new;
my $t   = Test::Mojo->new($app);

# Fresh DB
$app->pg->db->query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
$app->pg->migrations->from_dir('migrations')->migrate;

my $username = 'alice_' . int(rand(1_000_000));
my $password = 'correct-horse-battery';

# Register
$t->post_ok('/api/auth/register' => json => {
    username => $username,
    password => $password,
})->status_is(200)
  ->json_has('/access_token')
  ->json_has('/refresh_token');

my $access  = $t->tx->res->json->{access_token};
my $refresh = $t->tx->res->json->{refresh_token};

# /me with token
$t->get_ok('/api/auth/me' => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/user/username', $username);

# /me without token
$t->get_ok('/api/auth/me')->status_is(401);

# Login
$t->post_ok('/api/auth/login' => json => {
    username => $username,
    password => $password,
})->status_is(200)->json_has('/access_token');

# Login with wrong password
$t->post_ok('/api/auth/login' => json => {
    username => $username,
    password => 'wrong',
})->status_is(401);

# Refresh
$t->post_ok('/api/auth/refresh' => json => {
    refresh_token => $refresh,
})->status_is(200)->json_has('/access_token');

# Refresh with same (now-revoked) token — must fail (rotation)
$t->post_ok('/api/auth/refresh' => json => {
    refresh_token => $refresh,
})->status_is(401);

# Device token create
$t->post_ok('/api/auth/tokens' => { Authorization => "Bearer $access" }
    => json => { name => 'laptop' })
  ->status_is(201)
  ->json_like('/token', qr/^rsk_/);

done_testing;
