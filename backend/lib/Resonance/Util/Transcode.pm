package Resonance::Util::Transcode;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    transcode_or_original
    transcode_cache_stats
    clear_transcode_cache
    ffmpeg_available
);

use Mojo::File qw(path);
use IPC::Open3;
use Symbol qw(gensym);
use File::Spec;
use File::Find::Rule;

my %FORMATS = (
    mp3 => {
        ext   => 'mp3',
        mime  => 'audio/mpeg',
        codec => 'libmp3lame',
        container => 'mp3',
    },
    opus => {
        ext   => 'opus',
        mime  => 'audio/ogg',
        codec => 'libopus',
        container => 'ogg',
        extra => [ '-vbr', 'on', '-application', 'audio' ],
    },
    aac => {
        ext   => 'm4a',
        mime  => 'audio/mp4',
        codec => 'aac',
        container => 'mp4',
    },
);

my %VALID_BITRATES = map { $_ => 1 } (64, 96, 128, 192, 256, 320);

sub ffmpeg_available () {
    state $checked;
    return $checked if defined $checked;
    my $null = File::Spec->devnull;
    my $pid  = open my $fh, '-|', 'ffmpeg', '-version', '2>', $null;
    if ($pid) {
        waitpid $pid, 0;
        $checked = ($? == 0) ? 1 : 0;
    } else {
        $checked = 0;
    }
    return $checked;
}

sub _cache_dir ($app) {
    my $dir = $app->config->{transcode_cache_dir} // 'data/transcodes';
    path($dir)->make_path unless -d $dir;
    return $dir;
}

sub _cache_path ($app, $track_id, $mtime, $format, $bitrate) {
    my $dir = _cache_dir($app);
    my $sub = path($dir)->child("$track_id");
    $sub->make_path unless -d $sub;
    my $mtime_hex = sprintf '%x', $mtime;
    my $ext = $FORMATS{$format}{ext};
    return $sub->child("${mtime_hex}-${format}-${bitrate}.${ext}")->to_string;
}

sub _run_ffmpeg ($input, $output, $format, $bitrate) {
    my $spec = $FORMATS{$format} or return 0;

    my @cmd = (
        'ffmpeg',
        '-y',
        '-v', 'error',
        '-i', $input,
        '-vn',
        '-map_metadata', '0',
        '-c:a', $spec->{codec},
        '-b:a', "${bitrate}k",
        @{ $spec->{extra} // [] },
        '-f', $spec->{container},
        $output,
    );

    my $err_fh = gensym;
    my $pid = open3(my $in, my $out, $err_fh, @cmd);
    close $in;

    my $err = do { local $/; <$err_fh> // '' };
    close $out;
    close $err_fh;

    waitpid $pid, 0;
    return $? == 0 && -s $output ? 1 : 0;
}

sub transcode_or_original ($app, $track, $format, $bitrate) {
    my $original = $track->{path};

    return $original unless defined $format && length $format;
    return $original unless $FORMATS{$format};

    $bitrate = 192 unless defined $bitrate && $VALID_BITRATES{$bitrate};

    my $src_ext = $original =~ /\.([^.]+)$/ ? lc $1 : '';
    my $target_ext = $FORMATS{$format}{ext};
    if ($src_ext eq $target_ext || ($src_ext eq 'mp3' && $format eq 'mp3')) {
        return $original;
    }

    return $original unless ffmpeg_available();

    my $mtime = (stat $original)[9] or return $original;
    my $cached = _cache_path($app, $track->{id}, $mtime, $format, $bitrate);

    if (-f $cached && -s $cached) {
        return $cached;
    }

    my $tmp = "$cached.tmp.$$";
    my $ok = eval { _run_ffmpeg($original, $tmp, $format, $bitrate) };

    unless ($ok && -s $tmp) {
        unlink $tmp;
        $app->log->warn("transcode failed for track $track->{id} → $format/$bitrate");
        return $original;
    }

    rename $tmp, $cached or do {
        unlink $tmp;
        return $original;
    };

    return $cached;
}

sub transcode_cache_stats ($app) {
    my $dir = _cache_dir($app);
    my ($bytes, $files) = (0, 0);

    my @paths = File::Find::Rule->file->in($dir);
    for my $p (@paths) {
        $files++;
        $bytes += -s $p;
    }

    return {
        bytes => $bytes,
        files => $files,
        human => _human_size($bytes),
    };
}

sub clear_transcode_cache ($app) {
    my $dir = _cache_dir($app);
    my $removed = 0;

    my @paths = File::Find::Rule->file->in($dir);
    for my $p (@paths) {
        unlink $p and $removed++;
    }

    return $removed;
}

sub _human_size ($bytes) {
    return "$bytes B" if $bytes < 1024;
    return sprintf '%.1f KB', $bytes / 1024       if $bytes < 1024 ** 2;
    return sprintf '%.1f MB', $bytes / 1024 ** 2  if $bytes < 1024 ** 3;
    return sprintf '%.2f GB', $bytes / 1024 ** 3;
}

1;
