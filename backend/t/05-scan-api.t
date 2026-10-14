use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";

local $ENV{JWT_SECRET}        = 'a' x 32;
local $ENV{ALLOW_REGISTRATION}= 1;
local $ENV{POSTGRES_HOST}     = $ENV{POSTGRES_HOST}     // '127.0.0.1';
local $ENV{POSTGRES_PORT}     = $ENV{POSTGRES_PORT}     // 5432;
local $ENV{POSTGRES_DB}       = $ENV{POSTGRES_DB}       // 'resonance_test';
local $ENV{POSTGRES_USER}     = $ENV{POSTGRES_USER}     // 'resonance';
local $ENV{POSTGRES_PASSWORD} = $ENV{POSTGRES_PASSWORD} // 'change-me';
local $ENV{REDIS_URL}         = $ENV{REDIS_URL}         // 'redis://127.0.0.1:6379/0';

require Resonance;

my $app = Resonance->new;
my $t   = Test::Mojo->new($app);

# Fresh DB
$app->pg->db->query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
$app->pg->migrations->from_dir('migrations')->migrate;
$app->minion->backend->pg->migrations->name('minion')->migrate;

# Register + get token
$t->post_ok('/api/auth/register' => json => {
    username => 'scanner_' . int(rand(1_000_000)),
    password => 'correct-horse-battery',
})->status_is(200);

my $access = $t->tx->res->json->{access_token};

# /api/scan/active — empty
$t->get_ok('/api/scan/active' => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/jobs' => []);

# /api/scan — invalid path
$t->post_ok('/api/scan' => { Authorization => "Bearer $access" }
    => json => { path => '/nonexistent/path/xyz' })
  ->status_is(400)
  ->json_is('/error' => 'invalid_path');

# /api/scan — valid path (use /tmp as a safe existing dir)
$t->post_ok('/api/scan' => { Authorization => "Bearer $access" }
    => json => { path => '/tmp' })
  ->status_is(200)
  ->json_has('/job_id')
  ->json_is('/path' => '/tmp');

my $job_id = $t->tx->res->json->{job_id};

# /api/scan/jobs/:id — job exists
$t->get_ok("/api/scan/jobs/$job_id" => { Authorization => "Bearer $access" })
  ->status_is(200)
  ->json_is('/job/task' => 'scan');

# /api/scan/jobs/:id — unknown id
$t->get_ok('/api/scan/jobs/999999' => { Authorization => "Bearer $access" })
  ->status_is(404);

# /api/scan/jobs/:id — invalid id
$t->get_ok('/api/scan/jobs/abc' => { Authorization => "Bearer $access" })
  ->status_is(400);

# Unauthenticated
$t->get_ok('/api/scan/active')->status_is(401);

done_testing;
