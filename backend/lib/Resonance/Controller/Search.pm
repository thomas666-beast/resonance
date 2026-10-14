package Resonance::Controller::Search;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub search ($c) {
    my $q = $c->param('q');
    return $c->render(json => { artists => [], albums => [], tracks => [] })
        unless defined $q && length $q >= 2;

    my $like = "%$q%";
    my $db   = $c->pg->db;

    # Artists — trigram-friendly ILIKE on lower(name)
    my $artists = $db->query(
        q{SELECT id, name, sort_name
            FROM artists
           WHERE lower(name) LIKE lower(?) OR lower(coalesce(sort_name,'')) LIKE lower(?)
           ORDER BY similarity(lower(name), lower(?)) DESC NULLS LAST
           LIMIT 10},
        $like, $like, $q,
    )->hashes->to_array;

    # Albums — same approach
    my $albums = $db->query(
        q{SELECT a.id, a.title, a.year, a.artist_id, ar.name AS artist_name
            FROM albums a
            LEFT JOIN artists ar ON ar.id = a.artist_id
           WHERE lower(a.title) LIKE lower(?)
           ORDER BY similarity(lower(a.title), lower(?)) DESC NULLS LAST
           LIMIT 10},
        $like, $q,
    )->hashes->to_array;

    # Tracks — use full-text search tsvector first, fall back to ILIKE
    # ts_rank gives proper relevance scoring.
    my $tracks = $db->query(
        q{SELECT t.id, t.title, t.duration_ms,
                 t.album_id, al.title AS album_title,
                 t.artist_id, ar.name AS artist_name,
                 ts_rank(t.search_tsv, plainto_tsquery('simple', ?)) AS rank
            FROM tracks t
            LEFT JOIN albums  al ON al.id = t.album_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           WHERE t.search_tsv @@ plainto_tsquery('simple', ?)
              OR lower(t.title) LIKE lower(?)
           ORDER BY rank DESC NULLS LAST, t.title
           LIMIT 25},
        $q, $q, $like,
    )->hashes->to_array;

    $c->render(json => {
        artists => $artists,
        albums  => $albums,
        tracks  => $tracks,
        query   => $q,
    });
}

1;
