use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelper qw(fresh_app fresh_db seed_users seed_library);

my $app = fresh_app();
my $t   = Test::Mojo->new($app);
fresh_db($app);
my $users = seed_users($app);
my $lib   = seed_library($app, $users);

my $db = $app->pg->db;

require Resonance::Job::Scan;
Resonance::Job::Scan::_sync_track_genres($app, $lib->{tracks}[0]{id}, 'Rock');
Resonance::Job::Scan::_sync_track_genres($app, $lib->{tracks}[1]{id}, 'Rock');
Resonance::Job::Scan::_sync_track_genres($app, $lib->{tracks}[2]{id}, 'Jazz');

my $AUTH = 'u=alice&p=sub-pass-12345&v=1.16.1&c=test&f=json';

# Helper: unwrap the subsonic-response hash
sub sub_resp {
    my $json = shift;
    return $json->{'subsonic-response'};
}

# getGenres
$t->get_ok("/rest/getGenres?$AUTH")
  ->status_is(200)
  ->json_is('/subsonic-response/status' => 'ok')
  ->json_has('/subsonic-response/genres/genre');

my $genres = sub_resp($t->tx->res->json)->{genres}{genre};
is scalar @$genres, 2, 'two genres listed';

my %by_name = map { $_->{value} => $_ } @$genres;
ok $by_name{Rock}, 'Rock present';
ok $by_name{Jazz}, 'Jazz present';
is $by_name{Rock}{songCount}, 2, 'Rock has 2 songs';
is $by_name{Jazz}{songCount}, 1, 'Jazz has 1 song';

# getSongsByGenre
$t->get_ok("/rest/getSongsByGenre?genre=Rock&count=10&$AUTH")
  ->status_is(200)
  ->json_is('/subsonic-response/status' => 'ok');

my $songs = sub_resp($t->tx->res->json)->{songsByGenre}{song};
is scalar @$songs, 2, 'two rock songs returned';

# Case-insensitive match
$t->get_ok("/rest/getSongsByGenre?genre=rock&count=10&$AUTH");
my $lower = sub_resp($t->tx->res->json)->{songsByGenre}{song};
is scalar @$lower, 2, 'lowercase genre matches';

# Unknown genre
$t->get_ok("/rest/getSongsByGenre?genre=Nonexistent&count=10&$AUTH");
my $empty = sub_resp($t->tx->res->json)->{songsByGenre}{song};
is scalar @$empty, 0, 'unknown genre returns empty';

# Missing genre param
$t->get_ok("/rest/getSongsByGenre?$AUTH");
my $nogenre = sub_resp($t->tx->res->json)->{songsByGenre}{song};
is scalar @$nogenre, 0, 'missing genre returns empty';

# Missing tracks are filtered
$app->pg->db->query(
    'UPDATE tracks SET missing_at = now() WHERE id = ?',
    $lib->{tracks}[0]{id},
);

$t->get_ok("/rest/getSongsByGenre?genre=Rock&count=10&$AUTH");
my $after = sub_resp($t->tx->res->json)->{songsByGenre}{song};
is scalar @$after, 1, 'missing track excluded from genre list';

$t->get_ok("/rest/getGenres?$AUTH");
my $g2 = sub_resp($t->tx->res->json)->{genres}{genre};
my %by2 = map { $_->{value} => $_ } @$g2;
is $by2{Rock}{songCount}, 1, 'genre count reflects missing filter';

done_testing;
