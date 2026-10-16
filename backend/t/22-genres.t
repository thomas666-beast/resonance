use Mojo::Base -strict;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app fresh_db seed_users seed_library);

require Resonance::Job::Scan;

my $app = fresh_app();
fresh_db($app);
my $users = seed_users($app);
my $lib   = seed_library($app, $users);

my $track_id = $lib->{tracks}[0]{id};
my $db       = $app->pg->db;

# Helper: return the sorted list of genre names for a track
sub genres_for {
    my ($tid) = @_;
    my $rows = $db->query(
        q{SELECT g.name FROM tracks_genres tg
            JOIN genres g ON g.id = tg.genre_id
           WHERE tg.track_id = ?
           ORDER BY g.name},
        $tid,
    )->arrays->to_array;
    return [ map { $_->[0] } @$rows ];
}

# ── simple single genre ──────────────────────────────────

Resonance::Job::Scan::_sync_track_genres($app, $track_id, 'Rock');

is_deeply genres_for($track_id), ['Rock'], 'single genre linked';

# ── multi-genre string ───────────────────────────────────

Resonance::Job::Scan::_sync_track_genres($app, $track_id, 'Rock, Alternative, Indie');

is_deeply genres_for($track_id),
    ['Alternative', 'Indie', 'Rock'],
    'multi-genre split and linked';

# ── rescan replaces previous genres ──────────────────────

Resonance::Job::Scan::_sync_track_genres($app, $track_id, 'Jazz');

is_deeply genres_for($track_id), ['Jazz'], 'rescan replaces genres';

# ── case-insensitive deduplication ───────────────────────

Resonance::Job::Scan::_sync_track_genres($app, $track_id, 'jazz, JAZZ, Jazz');

my $n = $db->query(
    'SELECT count(*) AS n FROM tracks_genres WHERE track_id = ?', $track_id,
)->hash->{n};

is $n, 1, 'case variants collapse to a single genre';

my $stored = $db->query(
    q{SELECT g.name FROM tracks_genres tg
        JOIN genres g ON g.id = tg.genre_id
       WHERE tg.track_id = ? LIMIT 1},
    $track_id,
)->hash->{name};

is lc $stored, 'jazz', 'genre stored with original casing preserved';

# ── empty genre string clears links ──────────────────────

Resonance::Job::Scan::_sync_track_genres($app, $track_id, undef);

$n = $db->query(
    'SELECT count(*) AS n FROM tracks_genres WHERE track_id = ?', $track_id,
)->hash->{n};

is $n, 0, 'undefined genre clears all links';

# ── another track reuses the same genre row ──────────────

my $track2 = $lib->{tracks}[1]{id};

Resonance::Job::Scan::_sync_track_genres($app, $lib->{tracks}[0]{id}, 'Rock');
Resonance::Job::Scan::_sync_track_genres($app, $track2,           'Rock');

my $genre_count = $db->query(
    "SELECT count(*) AS n FROM genres WHERE lower(name) = 'rock'",
)->hash->{n};

is $genre_count, 1, 'two tracks with the same genre share one genre row';

done_testing;
