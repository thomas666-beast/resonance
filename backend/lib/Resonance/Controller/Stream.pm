package Resonance::Controller::Stream;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Util::Range qw(serve_file_with_range);

sub stream ($c) {
    my $id = $c->param('track_id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $track = $c->pg->db->query(
        'SELECT id, path, mime_type FROM tracks WHERE id = ?',
        $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'track_not_found' })
        unless $track;

    my $mime = $track->{mime_type};
    $mime = 'audio/mpeg' unless defined $mime && length $mime && $mime ne 'application/octet-stream';

    serve_file_with_range($c, $track->{path}, mime => $mime);
}

1;
