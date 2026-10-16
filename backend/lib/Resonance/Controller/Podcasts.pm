package Resonance::Controller::Podcasts;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# ── list subscribed feeds ────────────────────────────────

sub list_feeds ($c) {
    my $uid = $c->stash('current_user_id');

    my $feeds = $c->pg->db->query(
        q{SELECT f.id, f.feed_url, f.title, f.description, f.image_url,
                 f.author, f.website_url, f.last_fetched_at, f.last_error,
                 s.created_at AS subscribed_at,
                 (SELECT count(*) FROM podcast_episodes e WHERE e.feed_id = f.id) AS episode_count,
                 (SELECT max(published_at) FROM podcast_episodes e WHERE e.feed_id = f.id) AS latest_episode_at
            FROM user_podcast_subscriptions s
            JOIN podcast_feeds f ON f.id = s.feed_id
           WHERE s.user_id = ?
        ORDER BY lower(coalesce(f.title, f.feed_url))},
        $uid,
    )->hashes->to_array;

    $c->render(json => { feeds => $feeds });
}

# ── one feed + its episodes ──────────────────────────────

sub show_feed ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $uid = $c->stash('current_user_id');

    my $feed = $c->pg->db->query(
        q{SELECT f.id, f.feed_url, f.title, f.description, f.image_url,
                 f.author, f.website_url, f.last_fetched_at, f.last_error
            FROM podcast_feeds f
            JOIN user_podcast_subscriptions s
              ON s.feed_id = f.id AND s.user_id = ?
           WHERE f.id = ?},
        $uid, $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'feed_not_found' })
        unless $feed;

    my $episodes = $c->pg->db->query(
        q{SELECT id, guid, title, description, audio_url, duration_sec,
                 published_at, image_url, episode_number, season_number
            FROM podcast_episodes
           WHERE feed_id = ?
        ORDER BY published_at DESC NULLS LAST, id DESC},
        $id,
    )->hashes->to_array;

    $c->render(json => { feed => $feed, episodes => $episodes });
}

# ── subscribe ────────────────────────────────────────────

sub subscribe ($c) {
    my $uid  = $c->stash('current_user_id');
    my $body = $c->req->json // {};
    my $url  = $body->{feed_url};

    return $c->render(status => 400, json => { error => 'feed_url_required' })
        unless defined $url && length $url;
    return $c->render(status => 400, json => { error => 'invalid_feed_url' })
        unless $url =~ m{^https?://};

    # Does the feed row already exist?
    my $feed = $c->pg->db->query(
        'SELECT id FROM podcast_feeds WHERE feed_url = ?', $url,
    )->hash;

    my $feed_id;
    if ($feed) {
        $feed_id = $feed->{id};
    }
    else {
        # Create a placeholder feed; the refresh job fills in the details
        $feed_id = $c->pg->db->query(
            'INSERT INTO podcast_feeds (feed_url, created_by) VALUES (?, ?) RETURNING id',
            $url, $uid,
        )->hash->{id};
    }

    # Subscribe this user
    $c->pg->db->query(
        q{INSERT INTO user_podcast_subscriptions (user_id, feed_id)
          VALUES (?, ?) ON CONFLICT DO NOTHING},
        $uid, $feed_id,
    );

    # Kick off a refresh so the feed and its episodes get populated
    my $job_id = $c->minion->enqueue(podcast_refresh => [$feed_id]);

    $c->render(status => 201, json => {
        feed_id => $feed_id,
        job_id  => $job_id,
    });
}

# ── unsubscribe ──────────────────────────────────────────

sub unsubscribe ($c) {
    my $id  = $c->param('id');
    my $uid = $c->stash('current_user_id');

    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $n = $c->pg->db->query(
        'DELETE FROM user_podcast_subscriptions WHERE user_id = ? AND feed_id = ?',
        $uid, $id,
    )->rows;

    return $c->render(status => 404, json => { error => 'not_subscribed' })
        unless $n;

    # If no other user is subscribed, delete the feed itself
    my $still = $c->pg->db->query(
        'SELECT 1 FROM user_podcast_subscriptions WHERE feed_id = ? LIMIT 1',
        $id,
    )->array;

    unless ($still) {
        $c->pg->db->query('DELETE FROM podcast_feeds WHERE id = ?', $id);
    }

    $c->render(json => { ok => \1 });
}

# ── manual refresh ───────────────────────────────────────

sub refresh_feed ($c) {
    my $id  = $c->param('id');
    my $uid = $c->stash('current_user_id');

    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $sub = $c->pg->db->query(
        'SELECT 1 FROM user_podcast_subscriptions WHERE user_id = ? AND feed_id = ?',
        $uid, $id,
    )->array;

    return $c->render(status => 404, json => { error => 'not_subscribed' })
        unless $sub;

    my $job_id = $c->minion->enqueue(podcast_refresh => [$id]);
    $c->render(json => { job_id => $job_id });
}

sub refresh_all ($c) {
    my $uid = $c->stash('current_user_id');

    my $rows = $c->pg->db->query(
        'SELECT feed_id FROM user_podcast_subscriptions WHERE user_id = ?',
        $uid,
    )->arrays->map(sub { $_->[0] })->to_array;

    my @job_ids = map { $c->minion->enqueue(podcast_refresh => [$_]) } @$rows;

    $c->render(json => { queued => scalar @job_ids, job_ids => \@job_ids });
}

# ── one episode ──────────────────────────────────────────

sub show_episode ($c) {
    my $id  = $c->param('id');
    my $uid = $c->stash('current_user_id');

    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $ep = $c->pg->db->query(
        q{SELECT e.id, e.guid, e.title, e.description, e.audio_url,
                 e.duration_sec, e.published_at, e.image_url,
                 e.episode_number, e.season_number,
                 e.feed_id,
                 f.title AS feed_title, f.image_url AS feed_image_url
            FROM podcast_episodes e
            JOIN podcast_feeds f ON f.id = e.feed_id
            JOIN user_podcast_subscriptions s
              ON s.feed_id = f.id AND s.user_id = ?
           WHERE e.id = ?},
        $uid, $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'episode_not_found' })
        unless $ep;

    $c->render(json => { episode => $ep });
}

1;
