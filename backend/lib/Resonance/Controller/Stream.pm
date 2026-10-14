package Resonance::Controller::Stream;
use Mojo::Base 'Mojolicious::Controller', -signatures;

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

    my $path = $track->{path};
    return $c->render(status => 404, json => { error => 'file_missing' })
        unless -f $path;

    my $size = -s $path;
    my $mime = $track->{mime_type} // 'application/octet-stream';

    # Range support
    my $range = $c->req->headers->range;
    if ($range && $range =~ /^bytes=(\d*)-(\d*)$/) {
        my ($start, $end) = ($1, $2);
        $start = 0 unless length $start;
        $end   = $size - 1 if !length $end || $end >= $size;

        if ($start > $end || $start >= $size) {
            $c->res->headers->header('Content-Range' => "bytes */$size");
            return $c->render(status => 416, text => '');
        }

        my $length = $end - $start + 1;
        $c->res->headers->header('Content-Range'  => "bytes $start-$end/$size");
        $c->res->headers->header('Accept-Ranges'  => 'bytes');
        $c->res->headers->content_length($length);
        $c->res->headers->content_type($mime);
        $c->res->code(206);

        open my $fh, '<:raw', $path or return $c->render(status => 500, text => 'read error');
        seek $fh, $start, 0;
        my $buf;
        read $fh, $buf, $length;
        close $fh;

        return $c->render(data => $buf);
    }

    # No range — send whole file
    $c->res->headers->header('Accept-Ranges' => 'bytes');
    $c->res->headers->content_type($mime);
    $c->res->content->asset(Mojo::Asset::File->new(path => $path));
    $c->rendered(200);
}

1;
