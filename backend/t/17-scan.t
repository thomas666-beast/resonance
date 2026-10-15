use Mojo::Base -strict;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app fresh_db seed_users make_audio_file cleanup_audio_file);

my $app = fresh_app();
fresh_db($app);
my $users = seed_users($app);

my $audio = make_audio_file();
if (!$audio) {
    plan skip_all => 'ffmpeg not available for test file generation';
}

# Set up a temp scan directory with the audio file
my $tmpdir = "/tmp/resonance-scan-test-" . int(rand(1_000_000));
mkdir $tmpdir;
my $test_file = "$tmpdir/sample.mp3";
system('cp', $audio, $test_file);

# Insert scan_path row
my $sp = $app->pg->db->query(
    'INSERT INTO scan_paths (path) VALUES (?) RETURNING id',
    $tmpdir,
)->hash;

# Run the scan job synchronously — bypass Minion
use Resonance::Job::Scan ();

# We need to call the job body directly. Easiest way is via Minion
# in "perform" mode, but Minion API requires a real job. So we instantiate
# a fake job object.
{
    package FakeJob;
    sub new { bless { app => $_[1] }, $_[0] }
    sub app { $_[0]{app} }
    sub note { }
    sub fail { die "job failed: $_[1]\n" }
    sub finish { }
}

# The register() approach doesn't expose the inner sub, so trigger a real
# Minion job and run one worker iteration.
my $job_id = $app->minion->enqueue(scan => [$sp->{id}]);

# Perform the job synchronously
$app->minion->perform_jobs;

my $tracks = $app->pg->db->query('SELECT count(*) AS n FROM tracks')->hash->{n};
is $tracks, 1, 'scan ingested one track';

my $track = $app->pg->db->query('SELECT title, path FROM tracks LIMIT 1')->hash;
like $track->{title}, qr/sample/i, 'title derived from filename';
is $track->{path}, $test_file, 'path stored correctly';

# Idempotent — run again
my $job_id2 = $app->minion->enqueue(scan => [$sp->{id}]);
$app->minion->perform_jobs;

my $tracks_after = $app->pg->db->query('SELECT count(*) AS n FROM tracks')->hash->{n};
is $tracks_after, 1, 'rescan is idempotent';

cleanup_audio_file($audio);
unlink $test_file;
rmdir $tmpdir;

done_testing;
