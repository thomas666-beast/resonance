use Mojo::Base -strict;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app fresh_db seed_users seed_library);

use Resonance::Lyrics::Parser qw(parse_lrc is_lrc);
use Resonance::Lyrics::Provider qw(lyrics_for);

# ── parser ──────────────────────────────────────────────

my $lrc = <<'LRC';
[ar:Muse]
[ti:Hysteria]
[00:12.34] It's bugging me
[00:15.50] Grating me
[00:18.75] And twisting me around
LRC

ok is_lrc($lrc), 'LRC detected';

my $lines = parse_lrc($lrc);
is scalar @$lines, 3, 'three lyrics lines (metadata skipped)';

is $lines->[0]{start_ms}, 12340, 'first timestamp';
is $lines->[0]{value},    "It's bugging me", 'first line text';

is $lines->[1]{start_ms}, 15500, 'second timestamp';
is $lines->[2]{start_ms}, 18750, 'third timestamp';

# Multiple timestamps on one line
my $multi = "[00:10.00][00:20.00] repeated line\n";
my $m = parse_lrc($multi);
is scalar @$m, 2, 'two entries from a multi-timestamp line';
is $m->[0]{start_ms}, 10000, 'first of the multi-timestamp';
is $m->[1]{start_ms}, 20000, 'second of the multi-timestamp';

# Not LRC
ok !is_lrc("just plain lyrics\nno timestamps"), 'plain text is not LRC';

# ── provider: local .lrc file ──────────────────────────

my $app = fresh_app();
fresh_db($app);
my $users = seed_users($app);
my $lib   = seed_library($app, $users);

my $track_id = $lib->{tracks}[0]{id};
my $track = $app->pg->db->query(
    'SELECT id, title, path, duration_ms FROM tracks WHERE id = ?', $track_id,
)->hash;
$track->{artist_name} = 'Test Artist';

# Create a real .lrc file next to a fake path
my $tmpdir = "/tmp/resonance-lyrics-test-" . int(rand(1_000_000));
mkdir $tmpdir;
my $audio_path = "$tmpdir/song.mp3";
my $lrc_path   = "$tmpdir/song.lrc";
open my $fh, '>', $audio_path; print $fh 'fake'; close $fh;
open $fh, '>', $lrc_path;
print $fh "[00:01.00] Line one\n[00:02.00] Line two\n";
close $fh;

$track->{path} = $audio_path;
$app->pg->db->query(
    'UPDATE tracks SET path = ? WHERE id = ?', $audio_path, $track_id,
);

my $result = lyrics_for($app, $track);
ok $result, 'provider returned lyrics';
is $result->{source}, 'lrc', 'from lrc file';
ok $result->{synced}, 'marked synced';
is scalar @{ $result->{lines} }, 2, 'two lines parsed';

# Second call is served from the cache
my $result2 = lyrics_for($app, $track);
ok $result2->{cached}, 'second call served from cache';

# Cleanup
unlink $audio_path, $lrc_path;
rmdir $tmpdir;

# ── provider: no source ────────────────────────────────

my $no_track = {
    id => 99999, title => 'Nothing', path => '/nonexistent',
    artist_name => 'Nobody', album_title => undef, duration_ms => 0,
};
my $none = lyrics_for($app, $no_track);
ok !$none, 'no lyrics when no source has them';

done_testing;
