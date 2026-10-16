package Resonance::Controller::Subsonic::Lyrics;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(get_lyrics get_lyrics_by_song_id);

use Resonance::Subsonic::Format qw(subsonic_response subsonic_error id_value);
use Resonance::Lyrics::Provider  qw(lyrics_for);

# Modern OpenSubsonic endpoint. Response shape:
#   lyricsList.structuredLyrics[0].line[].{start,value}
sub get_lyrics_by_song_id ($c) {
    my $id = id_value($c->param('id'));
    return $c->render(json => subsonic_error(10, 'invalid id'))
        unless $id;

    my $track = $c->pg->db->query(
        q{SELECT t.id, t.title, t.path, t.duration_ms,
                 t.artist_id, ar.name AS artist_name,
                 t.album_id,  al.title AS album_title
            FROM tracks t
            LEFT JOIN artists ar ON ar.id = t.artist_id
            LEFT JOIN albums  al ON al.id = t.album_id
           WHERE t.id = ? AND t.missing_at IS NULL},
        $id,
    )->hash;

    return $c->render(json => subsonic_response({
        lyricsList => { structuredLyrics => [] },
    })) unless $track;

    my $result = lyrics_for($c->app, $track);

    return $c->render(json => subsonic_response({
        lyricsList => { structuredLyrics => [] },
    })) unless $result;

    my $lines;
    if ($result->{synced} && $result->{lines}) {
        $lines = [
            map { { start => 0 + $_->{start_ms}, value => $_->{value} } }
            @{ $result->{lines} }
        ];
    }
    else {
        # Plain text: one entry per line, no timestamp
        $lines = [
            map { { value => $_ } }
            grep { length }
            split /\r?\n/, $result->{content}
        ];
    }

    $c->render(json => subsonic_response({
        lyricsList => {
            structuredLyrics => [{
                displayArtist => $track->{artist_name},
                displayTitle  => $track->{title},
                lang          => 'und',
                synced        => $result->{synced} ? \1 : \0,
                line          => $lines,
            }],
        },
    }));
}

# Legacy endpoint. Query by artist + title, no timing.
sub get_lyrics ($c) {
    my $artist = $c->param('artist');
    my $title  = $c->param('title');

    return $c->render(json => subsonic_error(10, 'artist and title required'))
        unless defined $artist && defined $title
            && length $artist && length $title;

    my $track = $c->pg->db->query(
        q{SELECT t.id, t.title, t.path, t.duration_ms,
                 t.artist_id, ar.name AS artist_name,
                 t.album_id,  al.title AS album_title
            FROM tracks t
            LEFT JOIN artists ar ON ar.id = t.artist_id
            LEFT JOIN albums  al ON al.id = t.album_id
           WHERE lower(t.title) = lower(?)
             AND lower(ar.name) = lower(?)
             AND t.missing_at IS NULL
           LIMIT 1},
        $title, $artist,
    )->hash;

    unless ($track) {
        return $c->render(json => subsonic_response({
            lyrics => { artist => $artist, title => $title },
        }));
    }

    my $result = lyrics_for($c->app, $track);

    my $body = '';
    if ($result) {
        if ($result->{synced}) {
            # Strip timestamps for the legacy endpoint
            $body = join "\n", map { $_->{value} } @{ $result->{lines} // [] };
        }
        else {
            $body = $result->{content};
        }
    }

    $c->render(json => subsonic_response({
        lyrics => {
            artist => $artist,
            title  => $title,
            value  => $body,
        },
    }));
}

1;
