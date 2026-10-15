use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app fresh_db seed_users);

my $app = fresh_app();
my $t   = Test::Mojo->new($app);
fresh_db($app);
my $users = seed_users($app);

# Helper: reset the UA cookie jar between refresh calls.
# Mojo::UserAgent stores cookies from Set-Cookie responses and sends
# them automatically — which masks the rotation replay test.
sub wipe_cookies {
    $t->ua->cookie_jar(Mojo::UserAgent::CookieJar->new);
}

# ── register ─────────────────────────────────────────────

$t->post_ok('/api/auth/register' => json => {
    username => 'newuser',
    password => 'correct-horse-battery',
})->status_is(200)
  ->json_has('/access_token')
  ->json_is('/user/username' => 'newuser')
  ->json_is('/user/role'     => 'user');

$t->post_ok('/api/auth/register' => json => {
    username => 'newuser',
    password => 'correct-horse-battery',
})->status_is(409)->json_is('/error' => 'username_taken');

$t->post_ok('/api/auth/register' => json => { username => 'x' })
  ->status_is(400);

$t->post_ok('/api/auth/register' => json => {
    username => 'shorty',
    password => 'short',
})->status_is(400)->json_is('/error' => 'password_too_short');

# ── login ────────────────────────────────────────────────

$t->post_ok('/api/auth/login' => json => {
    username => 'alice',
    password => 'test-pass-12345',
})->status_is(200)
  ->json_has('/access_token')
  ->json_is('/user/username' => 'alice')
  ->json_is('/user/role'     => 'user');

my $access = $t->tx->res->json->{access_token};

# Wrong password
$t->post_ok('/api/auth/login' => json => {
    username => 'alice',
    password => 'wrong',
})->status_is(401)->json_is('/error' => 'invalid_credentials');

# Non-existent user
$t->post_ok('/api/auth/login' => json => {
    username => 'ghost',
    password => 'whatever',
})->status_is(401)->json_is('/error' => 'invalid_credentials');

# ── /me ──────────────────────────────────────────────────

$t->get_ok('/api/auth/me' => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/user/username' => 'alice')
  ->json_is('/user/role'     => 'user');

$t->get_ok('/api/auth/me')->status_is(401);

# ── refresh ──────────────────────────────────────────────

$t->post_ok('/api/auth/login' => json => {
    username => 'alice',
    password => 'test-pass-12345',
})->status_is(200);

my $hdr = $t->tx->res->headers->set_cookie;
my @set_cookies = ref $hdr eq 'ARRAY' ? @$hdr : ($hdr // ());
my ($rt) = map { /^resonance_refresh=([^;]+)/ ? $1 : () } @set_cookies;
ok $rt, 'refresh cookie issued on login';

# First refresh — explicit cookie, clean jar
wipe_cookies();
$t->post_ok('/api/auth/refresh' => {
    Cookie => "resonance_refresh=$rt",
})->status_is(200)->json_has('/access_token');

# Replay the SAME cookie — server must reject; clean jar to force the old value
wipe_cookies();
$t->post_ok('/api/auth/refresh' => {
    Cookie => "resonance_refresh=$rt",
})->status_is(401)->json_is('/error' => 'invalid_refresh_token');

# No cookie at all — clean jar
wipe_cookies();
$t->post_ok('/api/auth/refresh')->status_is(401)
  ->json_is('/error' => 'missing_refresh_token');

# ── logout ───────────────────────────────────────────────

$t->post_ok('/api/auth/login' => json => {
    username => 'alice',
    password => 'test-pass-12345',
})->status_is(200);
my $token = $t->tx->res->json->{access_token};

$t->post_ok('/api/auth/logout' => { Authorization => "Bearer $token" })
  ->status_is(200)
  ->json_is('/ok' => 1);

# ── device tokens ────────────────────────────────────────

$t->post_ok('/api/auth/login' => json => {
    username => 'alice',
    password => 'test-pass-12345',
})->status_is(200);
my $tok = $t->tx->res->json->{access_token};

$t->post_ok('/api/auth/tokens' => { Authorization => "Bearer $tok" }
    => json => { name => 'test-device' })
  ->status_is(201)
  ->json_like('/token', qr/^rsk_/);

$t->get_ok('/api/auth/tokens' => { Authorization => "Bearer $tok" })
  ->status_is(200)
  ->json_is('/tokens/0/name' => 'test-device');

my $device_id = $t->tx->res->json->{tokens}[0]{id};
$t->delete_ok("/api/auth/tokens/$device_id" => { Authorization => "Bearer $tok" })
  ->status_is(200);

$t->delete_ok('/api/auth/tokens/999999' => { Authorization => "Bearer $tok" })
  ->status_is(404);

done_testing;
