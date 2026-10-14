package Resonance::Controller::Cover;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub show ($c) {
    my $id = $c->param('album_id');
    return $c->render(status => 400, text => 'invalid id')
        unless defined $id && $id =~ /^\d+$/;

    my $album = $c->pg->db->query(
        'SELECT cover_path FROM albums WHERE id = ?', $id,
    )->hash;

    return $c->render(status => 404, text => 'no cover')
        unless $album && defined $album->{cover_path} && length $album->{cover_path};

    my $path = $album->{cover_path};

    return $c->render(status => 404, text => 'no cover')
        unless -f $path;

    # Sniff magic bytes for content-type
    my $mime = 'application/octet-stream';
    if (open my $fh, '<:raw', $path) {
        read $fh, my $magic, 8;
        close $fh;
        if ($magic =~ /^\xFF\xD8\xFF/) {
            $mime = 'image/jpeg';
        } elsif ($magic =~ /^\x89PNG\r\n\x1a\n/) {
            $mime = 'image/png';
        } elsif ($magic =~ /^GIF8/) {
            $mime = 'image/gif';
        }
    }

    $c->res->headers->content_type($mime);
    $c->res->headers->header('Cache-Control' => 'public, max-age=86400');
    $c->res->content->asset(Mojo::Asset::File->new(path => $path));
    $c->rendered(200);
}

1;
