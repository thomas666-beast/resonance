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

my $AUTH = 'u=alice&p=sub-pass-12345&v=1.16.1&c=test&f=json';

# ── auth ─────────────────────────────────────────────────

$t->get_ok("/rest/ping?$AUTH")
  ->status_is(200)
  ->json_is('/subsonic-response/status'  => 'ok')
  ->json_is('/subsonic-response/version' => '1.16.1');

# Wrong password
$t->get_ok('/rest/ping?u=alice&p=wrong&v=1.16.1&c=test&f=json')
  ->status_is(200)     # Subsonic always returns HTTP 200
  ->json_is('/subsonic-response/status' => 'failed')
  ->json_is('/subsonic-response/error/code' => 40);

# Legacy hex password
my $hex = unpack('H*', 'sub-pass-12345');
$t->get_ok("/rest/ping?u=alice&p=enc:$hex&v=1.16.1&c=test&f=json")
  ->json_is('/subsonic-response/status' => 'ok');

# ── license and folders ──────────────────────────────────

$t->get_ok("/rest/getLicense?$AUTH")
  ->json_is('/subsonic-response/license/valid' => 1);

$t->get_ok("/rest/getMusicFolders?$AUTH")
  ->json_is('/subsonic-response/musicFolders/musicFolder/0/name' => 'Media');

# ── browse ───────────────────────────────────────────────

$t->get_ok("/rest/getArtists?$AUTH")
  ->status_is(200)
  ->json_has('/subsonic-response/artists/index');

$t->get_ok("/rest/getIndexes?$AUTH")
  ->json_has('/subsonic-response/index');

my $album_id = $lib->{albums}[0]{id};
$t->get_ok("/rest/getAlbum?id=al-$album_id&$AUTH")
  ->json_is('/subsonic-response/album/name' => 'The Dark Side of the Moon')
  ->json_has('/subsonic-response/album/song');

my $artist_id = $lib->{artists}[0]{id};
$t->get_ok("/rest/getArtist?id=ar-$artist_id&$AUTH")
  ->json_is('/subsonic-response/artist/name' => 'Pink Floyd')
  ->json_has('/subsonic-response/artist/album');

my $track_id = $lib->{tracks}[0]{id};
$t->get_ok("/rest/getSong?id=tr-$track_id&$AUTH")
  ->json_is('/subsonic-response/song/title' => 'Track 1 on The Dark Side of the Moon');

# ── album list ───────────────────────────────────────────

$t->get_ok("/rest/getAlbumList2?type=newest&size=5&$AUTH")
  ->json_has('/subsonic-response/albumList2/album');

$t->get_ok("/rest/getAlbumList2?type=alphabeticalByName&size=3&$AUTH")
  ->json_is('/subsonic-response/albumList2/album/0/name' => 'Kid A');

# ── search ───────────────────────────────────────────────

$t->get_ok("/rest/search3?query=Dark&artistCount=5&albumCount=5&songCount=5&$AUTH")
  ->json_has('/subsonic-response/searchResult3/album');

# ── star / unstar ────────────────────────────────────────

$t->get_ok("/rest/star?id=tr-$track_id&$AUTH")
  ->json_is('/subsonic-response/status' => 'ok');

$t->get_ok("/rest/getStarred2?$AUTH")
  ->json_is('/subsonic-response/starred2/song/0/id' => "tr-$track_id");

$t->get_ok("/rest/unstar?id=tr-$track_id&$AUTH")
  ->json_is('/subsonic-response/status' => 'ok');

$t->get_ok("/rest/getStarred2?$AUTH")
  ->json_is('/subsonic-response/starred2/song' => []);

# ── playlists ────────────────────────────────────────────

$t->get_ok("/rest/getPlaylists?$AUTH")
  ->json_is('/subsonic-response/playlists/playlist/0/name' => 'Test Playlist');

my $pl_id = $lib->{playlist}{id};
$t->get_ok("/rest/getPlaylist?id=pl-$pl_id&$AUTH")
  ->json_is('/subsonic-response/playlist/name' => 'Test Playlist')
  ->json_has('/subsonic-response/playlist/entry');

# Create
$t->get_ok("/rest/createPlaylist?name=Curl&songId=tr-$track_id&$AUTH")
  ->json_is('/subsonic-response/playlist/name' => 'Curl')
  ->json_is('/subsonic-response/playlist/songCount' => 1);

# ── scrobble ─────────────────────────────────────────────

$t->get_ok("/rest/scrobble?id=tr-$track_id&submission=true&$AUTH")
  ->json_is('/subsonic-response/status' => 'ok');

my $plays = $app->pg->db->query(
    'SELECT count(*) AS n FROM user_plays WHERE user_id = ?',
    $users->{user}{id},
)->hash->{n};
is $plays, 1, 'play was logged';

# ── cover art ────────────────────────────────────────────

$t->get_ok("/rest/getCoverArt?id=al-$album_id&$AUTH")
  ->status_is(200)
  ->header_is('Content-Type' => 'image/png');  # placeholder

# ── unknown method ───────────────────────────────────────

$t->get_ok("/rest/nonsense?$AUTH")
  ->json_is('/subsonic-response/status' => 'failed');

done_testing;
