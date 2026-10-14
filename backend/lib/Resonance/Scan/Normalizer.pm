package Resonance::Scan::Normalizer;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(normalize_tags normalize_info);

# Per-format key mapping → our internal field names.
# Every key is uppercase, matching Audio::Scan's documented behavior.
my %MAP = (
    # ── ID3v2.4 (MP3, AIFF, WAV) ──
    title        => [qw/TIT2/],
    artist       => [qw/TPE1/],
    album        => [qw/TALB/],
    album_artist => [qw/TPE2/],
    track_number => [qw/TRCK/],
    disc_number  => [qw/TPOS/],
    year         => [qw/TDRC/],
    genre        => [qw/TCON/],

    # ── MP4 / M4A (iTunes atoms) ──
    # NAM/ART/ALB/etc. after Audio::Scan strips the © prefix
    # (see doc: "Keys starting with 0xA9 will have this character stripped")
    # Note: these OVERLAP with Vorbis names below — that's fine, we
    # just check both key sets per field.
    #   title: NAM
    #   artist: ART
    #   album: ALB
    #   album_artist: AART
    #   track_number: TRKN
    #   disc_number: DISK
    #   year: DAY
    #   genre: GNRE

    # ── Vorbis comments (FLAC, Ogg, Opus) ──
    #   title: TITLE
    #   artist: ARTIST
    #   album: ALBUM
    #   album_artist: ALBUMARTIST
    #   track_number: TRACKNUMBER
    #   disc_number: DISCNUMBER
    #   year: DATE
    #   genre: GENRE
);

# Full lookup table: field → list of possible source keys across formats
my %KEY_LOOKUP = (
    title        => [qw/TIT2 NAM TITLE/],
    artist       => [qw/TPE1 ART ARTIST/],
    album        => [qw/TALB ALB ALBUM/],
    album_artist => [qw/TPE2 AART ALBUMARTIST/],
    track_number => [qw/TRCK TRKN TRACKNUMBER/],
    disc_number  => [qw/TPOS DISK DISCNUMBER/],
    year         => [qw/TDRC DAY DATE/],
    genre        => [qw/TCON GNRE GENRE/],
);

sub normalize_tags ($tags) {
    return {} unless $tags && ref $tags eq 'HASH';

    my %out;

    for my $field (keys %KEY_LOOKUP) {
        my $value;
        for my $key (@{ $KEY_LOOKUP{$field} }) {
            next unless exists $tags->{$key};
            $value = $tags->{$key};
            last;
        }
        next unless defined $value;

        # Genre is our only multi-valued field in v1: join BEFORE collapse
        if ($field eq 'genre') {
            if (ref $value eq 'ARRAY') {
                $value = join(', ', @$value);
            }
            $out{$field} = "$value";
            next;
        }

        # Single-valued fields: collapse arrays first
        $value = $value->[0] if ref $value eq 'ARRAY';

        # Track / disc: "3" or "3/12"
        if ($field eq 'track_number' || $field eq 'disc_number') {
            $value = _parse_number($value);
            next unless defined $value;
        }

        # Year: "2024" or "2024-03-15"
        if ($field eq 'year') {
            $value = _parse_year($value);
            next unless defined $value;
        }

        $out{$field} = "$value";
    }

    return \%out;
}

sub normalize_info ($info) {
    return {} unless $info && ref $info eq 'HASH';

    my %out;
    my %info_map = (
        duration_ms => 'song_length_ms',
        bitrate     => 'bitrate',
        samplerate  => 'samplerate',
        channels    => 'channels',
    );

    for my $field (keys %info_map) {
        my $src = $info_map{$field};
        next unless defined $info->{$src};
        $out{$field} = $info->{$src};
    }

    return \%out;
}

# ── helpers ──

sub _parse_number ($value) {
    return undef unless defined $value && length $value;
    # "3/12" → 3 ; "3" → 3 ; "A1" → undef (non-numeric)
    $value =~ m{^\s*(\d+)} or return undef;
    return 0 + $1;
}

sub _parse_year ($value) {
    return undef unless defined $value && length $value;
    # "2024-03-15" → 2024 ; "2024" → 2024
    $value =~ m{^\s*(\d{4})} or return undef;
    return 0 + $1;
}

1;
