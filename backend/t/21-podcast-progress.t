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

# Seed a feed + episode directly
my $feed_id = $app->pg->db->query(
    "INSERT INTO podcast_feeds (feed_url, title) VALUES (?, ?) RETURNING id",
    'https://example.com/f.xml', 'Test Show',
)->hash->{id};

$app->pg->db->query(
    'INSERT INTO user_podcast_subscriptions (user_id, feed_id) VALUES (?, ?)',
    $users->{user}{id}, $feed_id,
);

my $ep_id = $app->pg->db->query(
    q{INSERT INTO podcast_episodes (feed_id, guid, title, audio_url, duration_sec)
      VALUES (?, 'ep-1', 'Test Episode', 'https://example.com/ep.mp3', 3600)
      RETURNING id},
    $feed_id,
)->hash->{id};

# No progress yet
$t->get_ok("/api/podcast-episodes/$ep_id/progress" => $auth)
  ->status_is(200)
  ->json_is('/progress/position_sec' => 0);

# Save progress
$t->put_ok("/api/podcast-episodes/$ep_id/progress" => $auth => json => {
    position_sec => 120,
    duration_sec => 3600,
})->status_is(200)->json_is('/ok' => 1);

# Read back
$t->get_ok("/api/podcast-episodes/$ep_id/progress" => $auth)
  ->json_is('/progress/position_sec' => 120)
  ->json_is('/progress/duration_sec' => 3600);

# Mark completed
$t->put_ok("/api/podcast-episodes/$ep_id/progress" => $auth => json => {
    position_sec => 3600,
    duration_sec => 3600,
    completed    => 1,
})->status_is(200);

$t->get_ok("/api/podcast-episodes/$ep_id/progress" => $auth)
  ->json_is('/progress/completed' => 1);

# Episode belongs to a feed alice isn't subscribed to
my $other_feed = $app->pg->db->query(
    "INSERT INTO podcast_feeds (feed_url) VALUES ('https://example.com/other.xml') RETURNING id"
)->hash->{id};
my $other_ep = $app->pg->db->query(
    q{INSERT INTO podcast_episodes (feed_id, guid, title, audio_url)
      VALUES (?, 'x', 'Other', 'https://example.com/x.mp3') RETURNING id},
    $other_feed,
)->hash->{id};

$t->get_ok("/api/podcast-episodes/$other_ep/progress" => $auth)
  ->status_is(200)->json_is('/progress/position_sec' => 0);   # no progress visible

$t->put_ok("/api/podcast-episodes/$other_ep/progress" => $auth => json => {
    position_sec => 60,
})->status_is(404);   # can't write progress for unsubscribed episode

done_testing;
