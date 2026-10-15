use Mojo::Base -strict;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app seed_library seed_users);

my $app = fresh_app();

# ── ffmpeg detection ─────────────────────────────────────

use Resonance::Util::Transcode qw(
    transcode_or_original ffmpeg_available
    transcode_cache_stats
);

my $have_ffmpeg = ffmpeg_available();
diag "ffmpeg " . ($have_ffmpeg ? "available" : "NOT available — some tests will skip");

# ── fallback when ffmpeg unavailable ─────────────────────

my $fake_track = { id => 99999, path => '/does/not/exist.mp3' };

is transcode_or_original($app, $fake_track, undef, undef),
   '/does/not/exist.mp3',
   'no format requested → original';

is transcode_or_original($app, $fake_track, 'bogus', undef),
   '/does/not/exist.mp3',
   'unsupported format → original';

is transcode_or_original($app, $fake_track, 'mp3', 192),
   '/does/not/exist.mp3',
   'source is mp3, target is mp3 → original (no transcode needed)';

# ── cache stats on empty dir ─────────────────────────────

my $stats = transcode_cache_stats($app);
ok exists $stats->{files}, 'stats has files count';
ok exists $stats->{bytes}, 'stats has byte count';
ok exists $stats->{human}, 'stats has human-readable size';

# ── real transcode (if ffmpeg) ───────────────────────────

SKIP: {
    skip "ffmpeg not available", 3 unless $have_ffmpeg;

    # Make a real mp3 source, then transcode to opus
    my $src = "/tmp/resonance-t16-src.mp3";
    system(
        'ffmpeg', '-y', '-v', 'error',
        '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=mono',
        '-t', '1', '-c:a', 'libmp3lame', '-b:a', '128k',
        $src,
    );
    ok -s $src, 'source file created';

    my $track = { id => 4242, path => $src };
    my $out = transcode_or_original($app, $track, 'opus', 96);

    isnt $out, $src, 'transcoded to a new path';
    ok -s $out, 'transcoded file exists and is non-empty';

    # Second call returns the cached path
    my $out2 = transcode_or_original($app, $track, 'opus', 96);
    is $out2, $out, 'second call returns cached path';

    unlink $src, $out;
}

done_testing;
