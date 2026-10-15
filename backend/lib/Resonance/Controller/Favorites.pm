package Resonance::Controller::Favorites;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub list ($c) {
    my $rows = $c->pg->db->query(
        q{SELECT t.id, t.title, t.track_number, t.disc_number,
                 t.duration_ms, t.album_id, t.artist_id,
                 al.title AS album_title, ar.name AS artist_name,
                 f.created_at AS favorited_at
            FROM favorites f
            JOIN tracks t   ON t.id  = f.track_id
            LEFT JOIN albums  al ON al.id = t.album_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           WHERE f.user_id = ?
             AND t.missing_at IS NULL
           ORDER BY f.created_at DESC},
        $c->stash('current_user_id'),
    )->hashes->to_array;

    $c->render(json => { tracks => $rows });
}

sub ids ($c) {
    # Lightweight list of favorited track ids — used by the frontend
    # to mark hearts without fetching full track rows.
    my $rows = $c->pg->db->query(
        q{SELECT f.track_id FROM favorites f
           JOIN tracks t ON t.id = f.track_id
          WHERE f.user_id = ? AND t.missing_at IS NULL},
        $c->stash('current_user_id'),
    )->arrays->map(sub { 0 + $_->[0] })->to_array;

    $c->render(json => { track_ids => $rows });
}

sub add ($c) {
    my $id = $c->param('track_id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless defined $id && $id =~ /^\d+$/;

    my $exists = $c->pg->db->query(
        'SELECT 1 FROM tracks WHERE id = ?', $id,
    )->array;

    return $c->render(status => 404, json => { error => 'track_not_found' })
        unless $exists;

    $c->pg->db->query(
        q{INSERT INTO favorites (user_id, track_id) VALUES (?, ?)
          ON CONFLICT DO NOTHING},
        $c->stash('current_user_id'), $id,
    );

    $c->render(json => { ok => \1, favorited => \1 });
}

sub remove ($c) {
    my $id = $c->param('track_id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless defined $id && $id =~ /^\d+$/;

    $c->pg->db->query(
        'DELETE FROM favorites WHERE user_id = ? AND track_id = ?',
        $c->stash('current_user_id'), $id,
    );

    $c->render(json => { ok => \1, favorited => \0 });
}

1;
