package Resonance::Controller::Subsonic::Podcasts;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    get_podcasts get_newest_podcasts get_podcast_episode
    refresh_podcasts create_podcast_channel delete_podcast_channel
    download_podcast_episode delete_podcast_episode
);

use Resonance::Subsonic::Format qw(subsonic_response subsonic_error);

# ── helpers ──────────────────────────────────────────────

sub _iso ($ts) {
    return undef unless defined $ts;
    $ts =~ s/ /T/;
    return $ts;
}

sub _format_channel ($row) {
    return {
        id          => 0 + $row->{id},
        url         => $row->{feed_url},
        title       => $row->{title} // $row->{feed_url},
        description => $row->{description},
        coverArt    => $row->{image_url},
        status      => 'completed',
        ($row->{website_url} ? (originalImageUrl => $row->{website_url}) : ()),
    };
}

sub _format_episode ($row) {
    my $r = {
        id          => 0 + $row->{id},
        channelId   => 0 + $row->{feed_id},
        title       => $row->{title},
        description => $row->{description},
        status      => 'completed',
        isDir       => \0,
        duration    => defined $row->{duration_sec} ? 0 + $row->{duration_sec} : 0,
        publishDate => _iso($row->{published_at}),
        streamId    => 'podcast-episode-' . $row->{id},
        coverArt    => $row->{image_url},
        suffix      => 'mp3',
        contentType => 'audio/mpeg',
    };
    return $r;
}

# ── list feeds ───────────────────────────────────────────

sub get_podcasts ($c) {
    my $uid = $c->stash('subsonic_user')->{id};

    my $feeds = $c->pg->db->query(
        q{SELECT f.id, f.feed_url, f.title, f.description, f.image_url,
                 f.website_url
            FROM user_podcast_subscriptions s
            JOIN podcast_feeds f ON f.id = s.feed_id
           WHERE s.user_id = ?
        ORDER BY lower(coalesce(f.title, f.feed_url))},
        $uid,
    )->hashes->to_array;

    my @channels;
    for my $f (@$feeds) {
        my $channel = _format_channel($f);

        my $eps = $c->pg->db->query(
            q{SELECT id, feed_id, title, description, duration_sec,
                     published_at, image_url
                FROM podcast_episodes
               WHERE feed_id = ?
            ORDER BY published_at DESC NULLS LAST, id DESC},
            $f->{id},
        )->hashes->to_array;

        $channel->{episode} = [ map { _format_episode($_) } @$eps ];
        push @channels, $channel;
    }

    $c->render(json => subsonic_response({
        podcasts => { channel => \@channels },
    }));
}

sub get_newest_podcasts ($c) {
    my $uid  = $c->stash('subsonic_user')->{id};
    my $size = $c->param('count') // 20;
    $size = 20 unless $size =~ /^\d+$/ && $size > 0 && $size <= 100;

    my $eps = $c->pg->db->query(
        q{SELECT e.id, e.feed_id, e.title, e.description, e.duration_sec,
                 e.published_at, e.image_url
            FROM podcast_episodes e
            JOIN user_podcast_subscriptions s
              ON s.feed_id = e.feed_id AND s.user_id = ?
        ORDER BY e.published_at DESC NULLS LAST, e.id DESC
           LIMIT ?},
        $uid, $size,
    )->hashes->to_array;

    $c->render(json => subsonic_response({
        newestPodcasts => {
            episode => [ map { _format_episode($_) } @$eps ],
        },
    }));
}

sub get_podcast_episode ($c) {
    my $uid = $c->stash('subsonic_user')->{id};
    my $id  = $c->param('id');

    return $c->render(json => subsonic_error(70, 'Episode not found'))
        unless defined $id && $id =~ /^\d+$/;

    my $ep = $c->pg->db->query(
        q{SELECT e.id, e.feed_id, e.title, e.description, e.duration_sec,
                 e.published_at, e.image_url
            FROM podcast_episodes e
            JOIN user_podcast_subscriptions s
              ON s.feed_id = e.feed_id AND s.user_id = ?
           WHERE e.id = ?},
        $uid, $id,
    )->hash;

    return $c->render(json => subsonic_error(70, 'Episode not found'))
        unless $ep;

    $c->render(json => subsonic_response({
        podcastEpisode => _format_episode($ep),
    }));
}

# ── subscribe / unsubscribe ──────────────────────────────

sub create_podcast_channel ($c) {
    my $uid = $c->stash('subsonic_user')->{id};
    my $url = $c->param('url');

    return $c->render(json => subsonic_error(10, 'url required'))
        unless defined $url && $url =~ m{^https?://};

    my $existing = $c->pg->db->query(
        'SELECT id FROM podcast_feeds WHERE feed_url = ?', $url,
    )->hash;

    my $feed_id;
    if ($existing) {
        $feed_id = $existing->{id};
    }
    else {
        $feed_id = $c->pg->db->query(
            'INSERT INTO podcast_feeds (feed_url, created_by) VALUES (?, ?) RETURNING id',
            $url, $uid,
        )->hash->{id};
    }

    $c->pg->db->query(
        q{INSERT INTO user_podcast_subscriptions (user_id, feed_id)
          VALUES (?, ?) ON CONFLICT DO NOTHING},
        $uid, $feed_id,
    );

    $c->minion->enqueue(podcast_refresh => [$feed_id]);

    $c->render(json => subsonic_response({}));
}

sub delete_podcast_channel ($c) {
    my $uid = $c->stash('subsonic_user')->{id};
    my $id  = $c->param('id');

    return $c->render(json => subsonic_error(10, 'invalid id'))
        unless defined $id && $id =~ /^\d+$/;

    my $n = $c->pg->db->query(
        'DELETE FROM user_podcast_subscriptions WHERE user_id = ? AND feed_id = ?',
        $uid, $id,
    )->rows;

    return $c->render(json => subsonic_error(70, 'not subscribed'))
        unless $n;

    $c->pg->db->query(
        q{DELETE FROM podcast_feeds f
           WHERE f.id = ?
             AND NOT EXISTS (SELECT 1 FROM user_podcast_subscriptions s
                              WHERE s.feed_id = f.id)},
        $id,
    );

    $c->render(json => subsonic_response({}));
}

# ── refresh ──────────────────────────────────────────────

sub refresh_podcasts ($c) {
    my $uid = $c->stash('subsonic_user')->{id};

    my $rows = $c->pg->db->query(
        'SELECT feed_id FROM user_podcast_subscriptions WHERE user_id = ?',
        $uid,
    )->arrays->map(sub { $_->[0] })->to_array;

    $c->minion->enqueue(podcast_refresh => [$_]) for @$rows;

    $c->render(json => subsonic_response({}));
}

# ── download / delete episode ────────────────────────────
# Clients that support offline playback call these.
# We download on demand when the client plays the episode,
# so download is a no-op that returns ok.

sub download_podcast_episode ($c) {
    $c->render(json => subsonic_response({}));
}

sub delete_podcast_episode ($c) {
    my $uid = $c->stash('subsonic_user')->{id};
    my $id  = $c->param('id');

    return $c->render(json => subsonic_error(10, 'invalid id'))
        unless defined $id && $id =~ /^\d+$/;

    # Only remove the local progress entry; keep the episode row
    $c->pg->db->query(
        'DELETE FROM podcast_progress WHERE user_id = ? AND episode_id = ?',
        $uid, $id,
    );

    $c->render(json => subsonic_response({}));
}

1;
