package Resonance::Controller::Podcasts;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::UserAgent;
use Mojo::URL;
use Mojo::File qw(path);
use Digest::SHA qw(sha256_hex);
use Resonance::Util::Range qw(serve_file_with_range);

my $UA_STRING         = 'Mozilla/5.0 (compatible; Resonance/0.01)';
my $MAX_DOWNLOAD_SIZE = 500 * 1024 * 1024;    # 500 MB

# ── helpers ──────────────────────────────────────────────

sub _valid_id ($id) {
    return defined $id && !ref $id && $id =~ /^\d+$/;
}

# Always returns a hashref, even if the client sent [] or a string.
sub _json_body ($c) {
    my $b = $c->req->json;
    return ref $b eq 'HASH' ? $b : {};
}

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
        unless _valid_id($id);

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
    my $body = _json_body($c);
    my $url  = $body->{feed_url};

    return $c->render(status => 400, json => { error => 'feed_url_required' })
        unless defined $url && !ref $url && length $url;

    my $u = Mojo::URL->new($url);
    return $c->render(status => 400, json => { error => 'invalid_feed_url' })
        unless length $url <= 2048
            && ($u->scheme // '') =~ /^https?$/
            && length($u->host // '');

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
        unless _valid_id($id);

    my $db = $c->pg->db;

    my $n = $db->query(
        'DELETE FROM user_podcast_subscriptions WHERE user_id = ? AND feed_id = ?',
        $uid, $id,
    )->rows;

    return $c->render(status => 404, json => { error => 'not_subscribed' })
        unless $n;

    # If no other user is subscribed, delete the feed itself.
    # Single atomic statement, so there's no check-then-delete race.
    $db->query(
        q{DELETE FROM podcast_feeds f
           WHERE f.id = ?
             AND NOT EXISTS (SELECT 1 FROM user_podcast_subscriptions s
                              WHERE s.feed_id = f.id)},
        $id,
    );

    $c->render(json => { ok => \1 });
}

# ── manual refresh ───────────────────────────────────────

sub refresh_feed ($c) {
    my $id  = $c->param('id');
    my $uid = $c->stash('current_user_id');

    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless _valid_id($id);

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
        unless _valid_id($id);

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

# ── audio cache + streaming ──────────────────────────────

sub _podcast_cache_dir ($c) {
    my $dir = $c->config->{podcast_cache_dir} // 'data/podcasts';
    path($dir)->make_path unless -d $dir;
    return $dir;
}

sub _episode_file ($c, $ep) {
    my $dir  = _podcast_cache_dir($c);
    my $hash = substr(sha256_hex($ep->{audio_url}), 0, 16);
    return "$dir/$ep->{id}-$hash.mp3";
}

sub _cached_episode_path ($c, $ep) {
    my $file = _episode_file($c, $ep);
    return (-f $file && -s $file) ? $file : undef;
}

# Non-blocking download. Returns a promise resolving to the cached file path.
sub _download_episode_p ($c, $ep) {
    my $log   = $c->app->log;
    my $final = _episode_file($c, $ep);
    my $tmp   = "$final.part.$$";

    $log->info("Podcast: downloading episode $ep->{id} from $ep->{audio_url}");

    my $ua = Mojo::UserAgent->new(
        connect_timeout    => 10,
        inactivity_timeout => 60,
        max_redirects      => 5,
        max_response_size  => $MAX_DOWNLOAD_SIZE,
    );
    $ua->transactor->name($UA_STRING);

    return $ua->get_p($ep->{audio_url})->then(sub ($tx) {
        my $res = $tx->result;    # dies on connection errors
        die 'HTTP ' . $res->code . "\n" unless $res->is_success;

        # Mojo keeps big bodies in a temp file, so this doesn't load
        # the whole episode into memory.
        my $asset = $res->content->asset;
        die "empty body\n" unless $asset->size;

        $asset->move_to($tmp);
        rename $tmp, $final or die "rename failed: $!\n";

        $log->info("Podcast: cached $final (" . (-s $final) . " bytes)");
        return $final;
    })->catch(sub ($err) {
        unlink $tmp if -f $tmp;
        chomp(my $msg = "$err");
        die "$msg\n";
    })->finally(sub {
        undef $ua;    # keep the UA alive until the transfer is done
    });
}

sub stream_episode ($c) {
    my $id  = $c->param('id');
    my $uid = $c->stash('current_user_id');

    return $c->render(status => 400, text => 'invalid id')
        unless _valid_id($id);

    my $ep = $c->pg->db->query(
        q{SELECT e.id, e.audio_url
            FROM podcast_episodes e
            JOIN podcast_feeds f ON f.id = e.feed_id
            JOIN user_podcast_subscriptions s
              ON s.feed_id = f.id AND s.user_id = ?
           WHERE e.id = ?},
        $uid, $id,
    )->hash;

    return $c->render(status => 404, text => 'episode not found')
        unless $ep;

    # Fast path: already cached
    if (my $cached = _cached_episode_path($c, $ep)) {
        return serve_file_with_range($c, $cached, mime => 'audio/mpeg');
    }

    # Slow path: download without blocking the event loop
    $c->render_later;
    _download_episode_p($c, $ep)->then(
        sub ($file) {
            serve_file_with_range($c, $file, mime => 'audio/mpeg');
        },
        sub ($err) {
            chomp $err;
            $c->app->log->warn("Podcast: download failed for episode $ep->{id}: $err");
            $c->render(status => 502, text => 'upstream unavailable');
        },
    )->catch(sub ($err) {
        $c->app->log->error("Podcast: serving episode $ep->{id} failed: $err");
    });
}

# ── playback progress ────────────────────────────────────

sub get_progress ($c) {
    my $id  = $c->param('id');
    my $uid = $c->stash('current_user_id');

    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless _valid_id($id);

    my $row = $c->pg->db->query(
        'SELECT position_sec, duration_sec, completed, updated_at
           FROM podcast_progress
          WHERE user_id = ? AND episode_id = ?',
        $uid, $id,
    )->hash;

    $c->render(json => {
        progress => $row // { position_sec => 0, duration_sec => undef, completed => 0 },
    });
}

sub set_progress ($c) {
    my $id  = $c->param('id');
    my $uid = $c->stash('current_user_id');

    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless _valid_id($id);

    my $body     = _json_body($c);
    my $pos      = $body->{position_sec} // 0;
    my $dur      = $body->{duration_sec};
    my $complete = $body->{completed} ? 1 : 0;

    return $c->render(status => 400, json => { error => 'invalid_position' })
        unless !ref $pos && $pos =~ /^\d+$/;

    # Verify the episode belongs to a feed the user subscribes to
    my $ok = $c->pg->db->query(
        q{SELECT 1
            FROM podcast_episodes e
            JOIN user_podcast_subscriptions s
              ON s.feed_id = e.feed_id AND s.user_id = ?
           WHERE e.id = ?},
        $uid, $id,
    )->array;

    return $c->render(status => 404, json => { error => 'episode_not_found' })
        unless $ok;

    $c->pg->db->query(
        q{INSERT INTO podcast_progress
              (user_id, episode_id, position_sec, duration_sec, completed, updated_at)
          VALUES (?, ?, ?, ?, ?, now())
          ON CONFLICT (user_id, episode_id) DO UPDATE
              SET position_sec = EXCLUDED.position_sec,
                  duration_sec = COALESCE(EXCLUDED.duration_sec, podcast_progress.duration_sec),
                  completed    = EXCLUDED.completed,
                  updated_at   = now()},
        $uid, $id, $pos,
        (defined $dur && !ref $dur && $dur =~ /^\d+$/) ? $dur : undef,
        $complete,
    );

    $c->render(json => { ok => \1 });
}

1;
