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

my $token = login_as($t, 'alice');
my $auth  = { Authorization => "Bearer $token" };

# ── empty list ───────────────────────────────────────────

$t->get_ok('/api/podcasts' => $auth)
  ->status_is(200)
  ->json_is('/feeds' => []);

# ── subscribe ────────────────────────────────────────────

$t->post_ok('/api/podcasts' => $auth => json => {
    feed_url => 'https://example.com/feed.xml',
})->status_is(201)
  ->json_has('/feed_id')
  ->json_has('/job_id');

my $feed_id = $t->tx->res->json->{feed_id};

# Idempotent — same URL, same feed
$t->post_ok('/api/podcasts' => $auth => json => {
    feed_url => 'https://example.com/feed.xml',
})->status_is(201);

is $t->tx->res->json->{feed_id}, $feed_id, 'same feed id on re-subscribe';

# Bad URL
$t->post_ok('/api/podcasts' => $auth => json => {
    feed_url => 'ftp://example.com/feed.xml',
})->status_is(400)->json_is('/error' => 'invalid_feed_url');

# Missing URL
$t->post_ok('/api/podcasts' => $auth => json => {})
  ->status_is(400)->json_is('/error' => 'feed_url_required');

# ── feed appears in list ─────────────────────────────────

$t->get_ok('/api/podcasts' => $auth)
  ->status_is(200)
  ->json_is('/feeds/0/id' => $feed_id)
  ->json_is('/feeds/0/feed_url' => 'https://example.com/feed.xml');

# ── show feed ────────────────────────────────────────────

$t->get_ok("/api/podcasts/$feed_id" => $auth)
  ->status_is(200)
  ->json_has('/feed')
  ->json_is('/episodes' => []);

# ── insert episodes manually and check they appear ───────

$app->pg->db->query(
    q{INSERT INTO podcast_episodes
          (feed_id, guid, title, audio_url, duration_sec, published_at)
      VALUES
          (?, 'ep-1', 'First Episode',  'https://example.com/ep1.mp3', 1800, '2024-01-01T00:00:00Z'),
          (?, 'ep-2', 'Second Episode', 'https://example.com/ep2.mp3', 2400, '2024-01-02T00:00:00Z')},
    $feed_id, $feed_id,
);

$t->get_ok("/api/podcasts/$feed_id" => $auth)
  ->status_is(200)
  ->json_is('/episodes/0/title' => 'Second Episode')  # newest first
  ->json_is('/episodes/1/title' => 'First Episode');

# ── refresh endpoint ─────────────────────────────────────

$t->post_ok("/api/podcasts/$feed_id/refresh" => $auth)
  ->status_is(200)->json_has('/job_id');

# ── unsubscribe ──────────────────────────────────────────

$t->delete_ok("/api/podcasts/$feed_id" => $auth)->status_is(200);

$t->get_ok('/api/podcasts' => $auth)->json_is('/feeds' => []);

# Unsubscribe again → 404
$t->delete_ok("/api/podcasts/$feed_id" => $auth)->status_is(404);

# ── auth required ────────────────────────────────────────

$t->get_ok('/api/podcasts')->status_is(401);

done_testing;
