package Resonance::Controller::Lyrics;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Lyrics::Provider qw(lyrics_for);

sub for_track ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless defined $id && $id =~ /^\d+$/;

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

    return $c->render(status => 404, json => { error => 'track_not_found' })
        unless $track;

    my $result = lyrics_for($c->app, $track);

    unless ($result) {
        return $c->render(json => {
            track_id => 0 + $track->{id},
            lyrics   => undef,
        });
    }

    $c->render(json => {
        track_id => 0 + $track->{id},
        lyrics   => {
            source  => $result->{source},
            synced  => $result->{synced} ? \1 : \0,
            content => $result->{content},
            lines   => $result->{lines},
        },
    });
}

1;
