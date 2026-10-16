package Resonance::Lyrics::Parser;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(parse_lrc is_lrc has_timestamps);

# Detect whether a string looks like LRC. Returns true if at least
# one line starts with [mm:ss.xx].
sub is_lrc ($text) {
    return 0 unless defined $text && length $text;
    return $text =~ /^\s*\[\d+:\d{2}(?:[.:]\d{1,3})?\]/m ? 1 : 0;
}

sub has_timestamps ($text) {
    return is_lrc($text);
}

# Parse LRC into an arrayref of { start_ms, value }.
# Multiple timestamps on one line produce multiple entries.
# Metadata lines like [ar:Artist] and [ti:Title] are skipped.
sub parse_lrc ($text) {
    return [] unless defined $text && length $text;

    my @lines;

    for my $raw (split /\r?\n/, $text) {
        next unless defined $raw && length $raw;

        # Collect every [mm:ss(.xx)] prefix on this line
        my @timestamps;
        my $rest = $raw;
        while ($rest =~ s/^\s*\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]//) {
            my ($m, $s, $frac) = ($1, $2, $3 // '');
            my $ms = $m * 60_000 + $s * 1000;
            if (length $frac) {
                # Normalize: ".5" = 500ms, ".50" = 500ms, ".500" = 500ms
                $ms += int(($frac . '00') =~ /^(\d{3})/ ? $1 : 0);
            }
            push @timestamps, $ms;
        }

        # Metadata line ([ar:...], [ti:...], [al:...], etc.) — skip
        next unless @timestamps;

        my $value = $rest;
        $value =~ s/^\s+|\s+$//g;
        next unless length $value;

        for my $ms (@timestamps) {
            push @lines, { start_ms => $ms, value => $value };
        }
    }

    # Sort by time, in case the file is not ordered
    @lines = sort { $a->{start_ms} <=> $b->{start_ms} } @lines;

    return \@lines;
}

1;
