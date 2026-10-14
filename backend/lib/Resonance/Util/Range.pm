package Resonance::Util::Range;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(serve_file_with_range);

use Mojo::Asset::File;
use Mojo::File qw(path);

# Serve a file to the response, honoring Range headers.
# Returns nothing; always calls $c->rendered(...) or renders an error.
sub serve_file_with_range ($c, $file_path, %opts) {
    my $mime        = $opts{mime}        // 'application/octet-stream';
    my $disposition = $opts{disposition};   # optional "attachment; filename=..."

    unless (-f $file_path) {
        return $c->render(status => 404, text => 'file not found');
    }

    my $size = -s $file_path;

    if (defined $disposition) {
        $c->res->headers->header('Content-Disposition' => $disposition);
    }

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

        open my $fh, '<:raw', $file_path
            or return $c->render(status => 500, text => 'read error');
        seek $fh, $start, 0;
        my $buf;
        read $fh, $buf, $length;
        close $fh;

        return $c->render(data => $buf);
    }

    # Full file
    $c->res->headers->header('Accept-Ranges' => 'bytes');
    $c->res->headers->content_type($mime);
    $c->res->content->asset(Mojo::Asset::File->new(path => $file_path));
    return $c->rendered(200);
}

1;
