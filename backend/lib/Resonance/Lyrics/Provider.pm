package Resonance::Lyrics::Provider;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(lyrics_for);

use Mojo::File qw(path);
use Mojo::UserAgent;
use Mojo::JSON   qw(decode_json);
use Resonance::Lyrics::Parser qw(parse_lrc is_lrc);

my $UA_STRING   = 'Mozilla/5.0 (compatible; Resonance/0.01)';
my $LRCLIB_BASE = 'https://lrclib.net/api';

# Look up lyrics for a track. Returns:
#   { source, synced, content, lines, cached }
# or undef if nothing found.
#
# $track is a hashref with: id, path, title, artist_name, album_title, duration_ms
sub lyrics_for ($app, $track) {
    return undef unless $track && $track->{id};

    # 1. Cache hit
    if (my $cached = _from_db($app, $track->{id})) {
        $cached->{lines}  = $cached->{synced} ? parse_lrc($cached->{content}) : undef;
        $cached->{cached} = 1;
        return $cached;
    }

    # 2. Local .lrc file next to the audio
    if (my $local = _from_lrc_file($track)) {
        _store($app, $track->{id}, $local->{source}, $local->{synced}, $local->{content});
        $local->{lines}  = $local->{synced} ? parse_lrc($local->{content}) : undef;
        $local->{cached} = 0;
        return $local;
    }

    # 3. LRCLIB
    if (my $remote = _from_lrclib($app, $track)) {
        _store($app, $track->{id}, $remote->{source}, $remote->{synced}, $remote->{content});
        $remote->{lines}  = $remote->{synced} ? parse_lrc($remote->{content}) : undef;
        $remote->{cached} = 0;
        return $remote;
    }

    return undef;
}

# ── sources ──────────────────────────────────────────────

sub _from_db ($app, $track_id) {
    my $row = $app->pg->db->query(
        'SELECT source, synced, content, fetched_at
           FROM track_lyrics
          WHERE track_id = ?',
        $track_id,
    )->hash;

    return undef unless $row;
    return {
        source     => $row->{source},
        synced     => $row->{synced} ? 1 : 0,
        content    => $row->{content},
        fetched_at => $row->{fetched_at},
    };
}

# Turn "/path/to/song.flac" into "/path/to/song.lrc"
# Case-insensitive on the extension, look for both .lrc and .LRC.
sub _from_lrc_file ($track) {
    my $path = $track->{path};
    return undef unless defined $path && length $path;
    return undef unless -f $path;

    (my $base = $path) =~ s/\.[^.]+$//;

    my $lrc;
    for my $ext (qw(lrc LRC)) {
        my $candidate = "$base.$ext";
        if (-f $candidate && -r $candidate) {
            $lrc = $candidate;
            last;
        }
    }
    return undef unless $lrc;

    my $content = eval { path($lrc)->slurp };
    return undef unless defined $content && length $content;

    # Handle non-UTF-8 LRC files gracefully
    unless (utf8::is_utf8($content)) {
        require Encode;
        $content = eval { Encode::decode('UTF-8', $content, 1) }
                // Encode::decode('ISO-8859-1', $content);
    }

    return {
        source  => 'lrc',
        synced  => is_lrc($content) ? 1 : 0,
        content => $content,
    };
}

sub _from_lrclib ($app, $track) {
    my $title  = $track->{title};
    my $artist = $track->{artist_name};

    return undef unless defined $title && length $title;
    return undef unless defined $artist && length $artist;

    my $ua = Mojo::UserAgent->new(
        connect_timeout    => 5,
        inactivity_timeout => 8,
        max_redirects      => 2,
    );
    $ua->transactor->name($UA_STRING);

    my %query = (
        artist_name => $artist,
        track_name  => $title,
    );
    $query{album_name} = $track->{album_title}
        if defined $track->{album_title} && length $track->{album_title};
    $query{duration} = int($track->{duration_ms} / 1000)
        if defined $track->{duration_ms} && $track->{duration_ms} > 0;

    my $url = Mojo::URL->new("$LRCLIB_BASE/get")->query(%query);

    my $tx = eval { $ua->get($url) };
    return undef unless $tx;

    if ($tx->error) {
        $app->log->debug("Lyrics: LRCLIB lookup failed: " . $tx->error->{message});
        return undef;
    }

    my $res = $tx->res;
    return undef unless $res->is_success;

    my $json = eval { decode_json($res->body) };
    return undef unless $json && ref $json eq 'HASH';

    if (my $synced = $json->{syncedLyrics}) {
        return { source => 'lrclib', synced => 1, content => $synced };
    }
    if (my $plain = $json->{plainLyrics}) {
        return { source => 'lrclib', synced => 0, content => $plain };
    }

    return undef;
}

# ── cache ────────────────────────────────────────────────

sub _store ($app, $track_id, $source, $synced, $content) {
    return unless defined $content && length $content;
    my $db = $app->pg->db;
    eval {
        $db->query(
            q{INSERT INTO track_lyrics (track_id, source, synced, content)
              VALUES (?, ?, ?, ?)
              ON CONFLICT (track_id) DO UPDATE
                  SET source     = EXCLUDED.source,
                      synced     = EXCLUDED.synced,
                      content    = EXCLUDED.content,
                      fetched_at = now()},
            $track_id, $source, $synced ? 1 : 0, $content,
        );
        1;
    } or $app->log->warn("Lyrics: cache write failed for track $track_id: $@");
}

1;
