package Resonance::Job::TranscodeCleanup;
use Mojo::Base -strict, -signatures;

use Mojo::File qw(path);

sub run ($app, $max_age_days = 30) {
    my $dir = $app->config->{transcode_cache_dir} // 'data/transcodes';
    return { removed => 0, freed => 0 } unless -d $dir;

    my $cutoff = time - ($max_age_days * 86400);
    my ($removed, $freed) = (0, 0);

    my $iter = path($dir)->list_tree->each;
    while (my $p = $iter->()) {
        next unless -f $p;
        my $mtime = (stat $p)[9] // 0;
        next if $mtime >= $cutoff;
        my $size = -s $p;
        if (unlink $p) {
            $removed++;
            $freed += $size;
        }
    }

    # Remove now-empty per-track directories
    my $dir_iter = path($dir)->list->each;
    while (my $sub = $dir_iter->()) {
        next unless -d $sub;
        rmdir $sub->to_string;
    }

    return { removed => $removed, freed => $freed };
}

1;
