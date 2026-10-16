package Resonance::Controller::Subsonic;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Subsonic::Auth qw(verify_subsonic_auth);
use Resonance::Subsonic::Format qw(
    subsonic_response subsonic_error
    format_music_folder
);
use Resonance::Controller::Subsonic::Browse ();
use Resonance::Controller::Subsonic::Media  ();
use Resonance::Controller::Subsonic::Lists  ();
use Resonance::Controller::Subsonic::Podcasts ();

# ── dispatcher ───────────────────────────────────────────

sub dispatch ($c) {
    my $method = $c->param('method') // '';
    my $params = { map { $_ => $c->param($_) } qw(u p t s v c f) };

    my $username = $c->param('u');
    my $user;
    if (defined $username && length $username) {
        $user = $c->pg->db->query(
            q{SELECT id, username, is_active, role, subsonic_password_enc
                FROM users WHERE lower(username) = lower(?)},
            $username,
        )->hash;
    }

    unless (verify_subsonic_auth($c->config->{jwt}{secret}, $user, $params)) {
        return $c->render(json => subsonic_error(40, 'Wrong username or password'));
    }

    $c->stash(subsonic_user => $user);

    my %handlers = (
        # Core
        ping            => \&_ping,
        getLicense      => \&_get_license,
        getMusicFolders => \&_get_music_folders,

        # Browsing
        getIndexes      => \&Resonance::Controller::Subsonic::Browse::get_indexes,
        getArtists      => \&Resonance::Controller::Subsonic::Browse::get_artists,
        getArtist       => \&Resonance::Controller::Subsonic::Browse::get_artist,
        getAlbum        => \&Resonance::Controller::Subsonic::Browse::get_album,
        getSong         => \&Resonance::Controller::Subsonic::Browse::get_song,
        getAlbumList    => \&Resonance::Controller::Subsonic::Browse::get_album_list,
        getAlbumList2   => \&Resonance::Controller::Subsonic::Browse::get_album_list2,
        getRandomSongs  => \&Resonance::Controller::Subsonic::Browse::get_random_songs,
        getSongsByGenre => \&Resonance::Controller::Subsonic::Browse::get_songs_by_genre,
        getGenres       => \&Resonance::Controller::Subsonic::Browse::get_genres,
        getArtistInfo2  => \&Resonance::Controller::Subsonic::Browse::get_artist_info2,
        getAlbumInfo2   => \&Resonance::Controller::Subsonic::Browse::get_album_info2,
        search3         => \&Resonance::Controller::Subsonic::Browse::search3,

        # Media
        stream          => \&Resonance::Controller::Subsonic::Media::stream,
        download        => \&Resonance::Controller::Subsonic::Media::download,
        getCoverArt     => \&Resonance::Controller::Subsonic::Media::get_cover_art,

        # Lists
        getPlaylists    => \&Resonance::Controller::Subsonic::Lists::get_playlists,
        getPlaylist     => \&Resonance::Controller::Subsonic::Lists::get_playlist,
        createPlaylist  => \&Resonance::Controller::Subsonic::Lists::create_playlist,
        updatePlaylist  => \&Resonance::Controller::Subsonic::Lists::update_playlist,
        deletePlaylist  => \&Resonance::Controller::Subsonic::Lists::delete_playlist,
        star            => \&Resonance::Controller::Subsonic::Lists::star,
        unstar          => \&Resonance::Controller::Subsonic::Lists::unstar,
        getStarred      => \&Resonance::Controller::Subsonic::Lists::get_starred2,
        getStarred2     => \&Resonance::Controller::Subsonic::Lists::get_starred2,
        scrobble        => \&Resonance::Controller::Subsonic::Lists::scrobble,
        getScanStatus   => \&Resonance::Controller::Subsonic::Lists::get_scan_status,
        startScan       => \&Resonance::Controller::Subsonic::Lists::start_scan,

        # Podcasts
        getPodcasts               => \&Resonance::Controller::Subsonic::Podcasts::get_podcasts,
        getNewestPodcasts         => \&Resonance::Controller::Subsonic::Podcasts::get_newest_podcasts,
        getPodcastEpisode         => \&Resonance::Controller::Subsonic::Podcasts::get_podcast_episode,
        createPodcastChannel      => \&Resonance::Controller::Subsonic::Podcasts::create_podcast_channel,
        deletePodcastChannel      => \&Resonance::Controller::Subsonic::Podcasts::delete_podcast_channel,
        refreshPodcasts           => \&Resonance::Controller::Subsonic::Podcasts::refresh_podcasts,
        downloadPodcastEpisode    => \&Resonance::Controller::Subsonic::Podcasts::download_podcast_episode,
        deletePodcastEpisode      => \&Resonance::Controller::Subsonic::Podcasts::delete_podcast_episode,
    );

    my $handler = $handlers{$method};
    unless ($handler) {
        return $c->render(json =>
            subsonic_error(0, "Method '$method' not implemented"));
    }

    return $handler->($c);
}

# ── core endpoints ───────────────────────────────────────

sub _ping ($c) {
    $c->render(json => subsonic_response({}));
}

sub _get_license ($c) {
    $c->render(json => subsonic_response({
        license => { valid => \1 },
    }));
}

sub _get_music_folders ($c) {
    $c->render(json => subsonic_response({
        musicFolders => {
            musicFolder => [ format_music_folder(1, 'Media') ],
        },
    }));
}

1;
