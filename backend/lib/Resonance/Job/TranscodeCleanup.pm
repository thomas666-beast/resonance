package Resonance::Job::TranscodeCleanup;
use Mojo::Base -strict, -signatures;

use File::Find::Rule;

sub run ($app, $max_age_days = 30) {
    my $dir = $app->config->{transcode_cache_dir} // 'data/transcodes';
    return { removed => 0, freed => 0 } unless -d $dir;

    my $cutoff = time - ($max_age_days * 86400);
    my ($removed, $freed) = (0, 0);

    my @paths = File::Find::Rule->file->in($dir);
    for my $p (@paths) {
        my $mtime = (stat $p)[9] // 0;
        next if $mtime >= $cutoff;
        my $size = -s $p;
        if (unlink $p) {
            $removed++;
            $freed += $size;
        }
    }

    # Remove empty per-track dirs
    if (opendir(my $dh, $dir)) {
        for my $entry (readdir $dh) {
            next if $entry eq '.' || $entry eq '..';
            my $sub = "$dir/$entry";
            next unless -d $sub;
            rmdir $sub;
        }
        closedir $dh;
    }

    return { removed => $removed, freed => $freed };
}

1;
