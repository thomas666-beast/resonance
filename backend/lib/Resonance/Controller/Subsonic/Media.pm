package Resonance::Controller::Subsonic::Media;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(stream download get_cover_art);

use Resonance::Util::Range qw(serve_file_with_range);
use Resonance::Util::Transcode qw(transcode_or_original);
use Resonance::Subsonic::Format qw(id_value);

use MIME::Base64 qw(decode_base64);

my $PLACEHOLDER_PNG = join '',
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk',
    'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

sub stream ($c)   { _serve($c, disposition => undef) }
sub download ($c) { _serve($c, disposition => 'attachment') }

sub _serve ($c, %opts) {
    my $id = id_value($c->param('id'));
    return $c->render(status => 400, text => 'invalid id') unless $id;

    my $track = $c->pg->db->query(
        'SELECT id, path, mime_type FROM tracks WHERE id = ?',
        $id,
    )->hash;
    return $c->render(status => 404, text => 'track not found') unless $track;

    # Subsonic params: format (mp3, opus, aac) and maxBitRate (kbps)
    my $format  = $c->param('format');
    my $bitrate = $c->param('maxBitRate') // $c->param('bitrate');

    my $serve_path = transcode_or_original($c->app, $track, $format, $bitrate);

    my $mime = $track->{mime_type};
    if (defined $format && $serve_path ne $track->{path}) {
        $mime = {
            mp3  => 'audio/mpeg',
            opus => 'audio/ogg',
            aac  => 'audio/mp4',
        }->{$format} // $mime;
    }
    $mime = 'audio/mpeg' unless defined $mime && length $mime && $mime ne 'application/octet-stream';

    my $disposition;
    if ($opts{disposition}) {
        my $name = $track->{path};
        $name =~ s{.*/}{};
        $name =~ s/[^\w.\-]/_/g;
        $name = 'track' unless length $name;
        $disposition = qq{attachment; filename="$name"};
    }

    serve_file_with_range(
        $c, $serve_path,
        mime => $mime,
        (defined $disposition ? (disposition => $disposition) : ()),
    );
}

sub get_cover_art ($c) {
    my $id_param = $c->param('id') // '';
    my $id = id_value($id_param);

    my $album_id;
    if (defined $id && $id_param =~ /^al-\d+$/) { $album_id = $id }
    elsif (defined $id && $id_param =~ /^\d+$/) { $album_id = $id }

    my $path;
    if ($album_id) {
        my $row = $c->pg->db->query(
            'SELECT cover_path FROM albums WHERE id = ?', $album_id,
        )->hash;
        $path = $row->{cover_path} if $row && defined $row->{cover_path};
    }

    if (defined $path && length $path && -f $path) {
        $c->res->headers->content_type(_sniff_mime($path));
        $c->res->headers->header('Cache-Control' => 'public, max-age=86400');
        $c->res->content->asset(Mojo::Asset::File->new(path => $path));
        return $c->rendered(200);
    }

    $c->res->headers->content_type('image/png');
    $c->res->headers->header('Cache-Control' => 'public, max-age=3600');
    return $c->render(data => decode_base64($PLACEHOLDER_PNG));
}

sub _sniff_mime ($path) {
    return 'image/jpeg' if $path =~ /\.jpe?g$/i;
    return 'image/png'  if $path =~ /\.png$/i;
    return 'image/gif'  if $path =~ /\.gif$/i;
    return 'image/jpeg';
}

1;
