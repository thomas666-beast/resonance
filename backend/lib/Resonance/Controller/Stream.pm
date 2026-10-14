package Resonance::Controller::Stream;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Util::Range qw(serve_file_with_range);
use Resonance::Util::Transcode qw(transcode_or_original);

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

    my $format  = $c->param('format');
    my $bitrate = $c->param('bitrate');

    my $serve_path = transcode_or_original($c->app, $track, $format, $bitrate);

    # If we served a transcode, override the MIME type
    my $mime = $track->{mime_type};
    if (defined $format && $serve_path ne $track->{path}) {
        $mime = {
            mp3  => 'audio/mpeg',
            opus => 'audio/ogg',
            aac  => 'audio/mp4',
        }->{$format} // $mime;
    }
    $mime = 'audio/mpeg' unless defined $mime && length $mime && $mime ne 'application/octet-stream';

    serve_file_with_range($c, $serve_path, mime => $mime);
}

1;
