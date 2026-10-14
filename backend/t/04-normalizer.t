use Mojo::Base -strict;
use Test::More;

use lib 'lib';
use Resonance::Scan::Normalizer qw(normalize_tags normalize_info);

# ── MP3 (ID3v2.4) ──
{
    my $tags = normalize_tags({
        TIT2 => 'Bohemian Rhapsody',
        TPE1 => 'Queen',
        TALB => 'A Night at the Opera',
        TPE2 => 'Queen',
        TRCK => '11/12',
        TPOS => '1/1',
        TDRC => '1975-10-31',
        TCON => 'Rock',
    });
    is $tags->{title},        'Bohemian Rhapsody', 'mp3 title';
    is $tags->{artist},       'Queen',              'mp3 artist';
    is $tags->{album},        'A Night at the Opera', 'mp3 album';
    is $tags->{track_number}, 11,                  'mp3 track parsed from 11/12';
    is $tags->{disc_number},  1,                   'mp3 disc parsed from 1/1';
    is $tags->{year},         1975,                'mp3 year stripped from full date';
    is $tags->{genre},        'Rock',              'mp3 genre';
}

# ── M4A (MP4 atoms) ──
{
    my $tags = normalize_tags({
        NAM  => 'Take Five',
        ART  => 'The Dave Brubeck Quartet',
        ALB  => 'Time Out',
        AART => 'The Dave Brubeck Quartet',
        TRKN => '3/7',
        DISK => '1/1',
        DAY  => '1959',
        GNRE => 'Jazz',
    });
    is $tags->{title},        'Take Five',      'm4a title';
    is $tags->{artist},       'The Dave Brubeck Quartet', 'm4a artist';
    is $tags->{track_number}, 3,                'm4a track parsed';
    is $tags->{year},         1959,             'm4a year';
}

# ── FLAC (Vorbis comments) ──
{
    my $tags = normalize_tags({
        TITLE       => 'Teardrop',
        ARTIST      => 'Massive Attack',
        ALBUM       => 'Mezzanine',
        ALBUMARTIST => 'Massive Attack',
        TRACKNUMBER => '1',
        DISCNUMBER  => '1',
        DATE        => '1998',
        GENRE       => 'Trip-Hop',
    });
    is $tags->{title},        'Teardrop',       'flac title';
    is $tags->{album_artist}, 'Massive Attack', 'flac album artist';
    is $tags->{track_number}, 1,                'flac track';
    is $tags->{genre},        'Trip-Hop',       'flac genre';
}

# ── Vorbis array values ──
{
    my $tags = normalize_tags({
        TITLE  => ['Track A'],
        ARTIST => ['Artist A', 'Artist B'],
        GENRE  => ['Rock', 'Alternative'],
    });
    is $tags->{title},  'Track A',             'array title takes first';
    is $tags->{artist}, 'Artist A',            'array artist takes first';
    is $tags->{genre},  'Rock, Alternative',   'array genre joined';
}

# ── Missing tags ──
{
    my $tags = normalize_tags({});
    is_deeply $tags, {}, 'empty tags → empty hash';

    my $tags2 = normalize_tags(undef);
    is_deeply $tags2, {}, 'undef tags → empty hash';
}

# ── Malformed numbers ──
{
    my $tags = normalize_tags({ TRCK => 'A1', TRACKNUMBER => 'not-a-number' });
    ok !exists $tags->{track_number}, 'non-numeric track rejected';
}

# ── Info block ──
{
    my $info = normalize_info({
        song_length_ms => 267000,
        bitrate        => 320000,
        samplerate     => 44100,
        channels       => 2,
        audio_offset   => 1024,   # ignored
    });
    is $info->{duration_ms}, 267000, 'duration';
    is $info->{bitrate},     320000, 'bitrate';
    is $info->{samplerate},  44100,  'samplerate';
    is $info->{channels},    2,      'channels';
    ok !exists $info->{audio_offset}, 'irrelevant fields ignored';
}

done_testing;
