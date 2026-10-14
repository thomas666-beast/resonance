package Resonance::Controller::Playlists;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# ── helpers ──────────────────────────────────────────────

sub _load_owned ($c, $id) {
    my $pl = $c->pg->db->query(
        'SELECT * FROM playlists WHERE id = ? AND user_id = ?',
        $id, $c->stash('current_user_id'),
    )->hash;
    return $pl;
}

sub _load_visible ($c, $id) {
    my $pl = $c->pg->db->query(
        q{SELECT * FROM playlists
           WHERE id = ? AND (user_id = ? OR is_public = TRUE)},
        $id, $c->stash('current_user_id'),
    )->hash;
    return $pl;
}

sub _track_count ($c, $playlist_id) {
    return $c->pg->db->query(
        'SELECT count(*) AS n FROM playlist_tracks WHERE playlist_id = ?',
        $playlist_id,
    )->hash->{n} + 0;
}

# ── endpoints ────────────────────────────────────────────

sub list ($c) {
    my $uid = $c->stash('current_user_id');
    my $rows = $c->pg->db->query(
        q{SELECT p.id, p.name, p.description, p.is_public, p.created_at,
                 (SELECT count(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) AS track_count
            FROM playlists p
           WHERE p.user_id = ? OR p.is_public = TRUE
           ORDER BY p.created_at DESC},
        $uid,
    )->hashes->to_array;

    $c->render(json => { playlists => $rows });
}

sub show ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $pl = _load_visible($c, $id)
        or return $c->render(status => 404, json => { error => 'playlist_not_found' });

    my $tracks = $c->pg->db->query(
        q{SELECT t.id, t.title, t.track_number, t.disc_number,
                 t.duration_ms, t.album_id, t.artist_id,
                 al.title AS album_title, ar.name AS artist_name,
                 pt.position
            FROM playlist_tracks pt
            JOIN tracks t   ON t.id  = pt.track_id
            LEFT JOIN albums  al ON al.id = t.album_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           WHERE pt.playlist_id = ?
           ORDER BY pt.position},
        $id,
    )->hashes->to_array;

    $c->render(json => { playlist => $pl, tracks => $tracks });
}

sub create ($c) {
    my $body = $c->req->json // {};
    my $name = $body->{name};
    return $c->render(status => 400, json => { error => 'name_required' })
        unless defined $name && length $name;

    my $pl = $c->pg->db->query(
        q{INSERT INTO playlists (user_id, name, description, is_public)
          VALUES (?, ?, ?, ?)
          RETURNING id, name, description, is_public, created_at},
        $c->stash('current_user_id'),
        $name,
        $body->{description},
        $body->{is_public} ? 1 : 0,
    )->hash;

    $pl->{track_count} = 0;
    $c->render(status => 201, json => { playlist => $pl });
}

sub update ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    _load_owned($c, $id)
        or return $c->render(status => 404, json => { error => 'playlist_not_found' });

    my $body = $c->req->json // {};
    my $pl = $c->pg->db->query(
        q{UPDATE playlists
              SET name        = COALESCE(?, name),
                  description = COALESCE(?, description),
                  is_public   = COALESCE(?, is_public),
                  updated_at  = now()
            WHERE id = ?
        RETURNING id, name, description, is_public, created_at},
        $body->{name},
        $body->{description},
        exists $body->{is_public} ? ($body->{is_public} ? 1 : 0) : undef,
        $id,
    )->hash;

    $c->render(json => { playlist => $pl });
}

sub remove ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    _load_owned($c, $id)
        or return $c->render(status => 404, json => { error => 'playlist_not_found' });

    $c->pg->db->query('DELETE FROM playlists WHERE id = ?', $id);
    $c->render(json => { ok => \1 });
}

sub add_track ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    _load_owned($c, $id)
        or return $c->render(status => 404, json => { error => 'playlist_not_found' });

    my $body = $c->req->json // {};
    my $tid = $body->{track_id};
    return $c->render(status => 400, json => { error => 'track_id_required' })
        unless defined $tid && $tid =~ /^\d+$/;

    my $track_ok = $c->pg->db->query(
        'SELECT 1 FROM tracks WHERE id = ?', $tid,
    )->array;
    return $c->render(status => 404, json => { error => 'track_not_found' })
        unless $track_ok;

    my $next = $c->pg->db->query(
        'SELECT COALESCE(MAX(position), 0) + 1 AS p FROM playlist_tracks WHERE playlist_id = ?',
        $id,
    )->hash->{p};

    $c->pg->db->query(
        q{INSERT INTO playlist_tracks (playlist_id, track_id, position)
          VALUES (?, ?, ?)
          ON CONFLICT DO NOTHING},
        $id, $tid, $next,
    );

    $c->render(json => {
        ok => \1,
        position => $next + 0,
        track_count => _track_count($c, $id),
    });
}

sub remove_track ($c) {
    my $id  = $c->param('id');
    my $tid = $c->param('track_id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/ && $tid =~ /^\d+$/;

    _load_owned($c, $id)
        or return $c->render(status => 404, json => { error => 'playlist_not_found' });

    my $n = $c->pg->db->query(
        'DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?',
        $id, $tid,
    )->rows;

    return $c->render(status => 404, json => { error => 'track_not_in_playlist' })
        unless $n;

    $c->render(json => { ok => \1, track_count => _track_count($c, $id) });
}

sub reorder ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    _load_owned($c, $id)
        or return $c->render(status => 404, json => { error => 'playlist_not_found' });

    my $body = $c->req->json // {};
    my $order = $body->{track_ids};
    return $c->render(status => 400, json => { error => 'track_ids_required' })
        unless ref $order eq 'ARRAY';

    my $db = $c->pg->db;
    $db->query('BEGIN');
    eval {
        my $pos = 1;
        for my $tid (@$order) {
            next unless defined $tid && $tid =~ /^\d+$/;
            $db->query(
                'UPDATE playlist_tracks SET position = ? WHERE playlist_id = ? AND track_id = ?',
                $pos, $id, $tid,
            );
            $pos++;
        }
        $db->query('COMMIT');
        1;
    } or do {
        my $err = $@;
        $db->query('ROLLBACK');
        return $c->render(status => 500, json => { error => 'reorder_failed', detail => "$err" });
    };

    $c->render(json => { ok => \1 });
}

1;
