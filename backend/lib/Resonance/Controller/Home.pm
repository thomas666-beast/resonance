package Resonance::Controller::Home;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my $uid = $c->stash('current_user_id');
    my $db  = $c->pg->db;

    # Recently played — distinct tracks, most recent first
    my $recent_played = $db->query(
        q{SELECT t.id, t.title, t.duration_ms,
                 t.album_id, al.title AS album_title,
                 t.artist_id, ar.name AS artist_name,
                 MAX(p.played_at) AS last_played
            FROM user_plays p
            JOIN tracks  t  ON t.id  = p.track_id
            LEFT JOIN albums  al ON al.id = t.album_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           WHERE p.user_id = ?
             AND t.missing_at IS NULL
        GROUP BY t.id, t.title, t.duration_ms,
                 t.album_id, al.title,
                 t.artist_id, ar.name
        ORDER BY last_played DESC
           LIMIT 12},
        $uid,
    )->hashes->to_array;

    # Recently added — newest tracks in the library
    my $recent_added = $db->query(
        q{SELECT t.id, t.title, t.duration_ms,
                 t.album_id, al.title AS album_title,
                 t.artist_id, ar.name AS artist_name
            FROM tracks t
            LEFT JOIN albums  al ON al.id = t.album_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           WHERE t.missing_at IS NULL
           ORDER BY t.created_at DESC
           LIMIT 12},
    )->hashes->to_array;

    # Recent albums — only albums that still have at least one active track
    my $recent_albums = $db->query(
        q{SELECT a.id, a.title, a.year,
                 a.artist_id, ar.name AS artist_name
            FROM albums a
            LEFT JOIN artists ar ON ar.id = a.artist_id
           WHERE EXISTS (SELECT 1 FROM tracks t
                          WHERE t.album_id = a.id
                            AND t.missing_at IS NULL)
           ORDER BY a.created_at DESC
           LIMIT 6},
    )->hashes->to_array;

    # Favorites preview — active tracks only
    my $favorites = $db->query(
        q{SELECT t.id, t.title, t.duration_ms,
                 t.album_id, al.title AS album_title,
                 t.artist_id, ar.name AS artist_name
            FROM favorites f
            JOIN tracks  t  ON t.id  = f.track_id
            LEFT JOIN albums  al ON al.id = t.album_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           WHERE f.user_id = ?
             AND t.missing_at IS NULL
        ORDER BY f.created_at DESC
           LIMIT 6},
        $uid,
    )->hashes->to_array;

    # Playlists preview
    my $playlists = $db->query(
        q{SELECT p.id, p.name,
                 (SELECT count(*) FROM playlist_tracks pt
                    JOIN tracks t ON t.id = pt.track_id
                   WHERE pt.playlist_id = p.id
                     AND t.missing_at IS NULL) AS track_count
            FROM playlists p
           WHERE p.user_id = ?
        ORDER BY p.updated_at DESC NULLS LAST, p.created_at DESC
           LIMIT 4},
        $uid,
    )->hashes->to_array;

    $c->render(json => {
        recently_played => $recent_played,
        recently_added  => $recent_added,
        recent_albums   => $recent_albums,
        favorites       => $favorites,
        playlists       => $playlists,
    });
}

1;
