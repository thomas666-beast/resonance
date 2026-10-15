package Resonance::Controller::Subsonic::Lists;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    get_playlists get_playlist create_playlist update_playlist delete_playlist
    star unstar get_starred2
    scrobble get_scan_status start_scan
);

use Resonance::Subsonic::Format qw(
    subsonic_response subsonic_error
    id_for id_value format_song format_playlist
);

sub _song_rows ($db, $where, $order, @args) {
    return $db->query(
        qq{SELECT t.id, t.title, t.track_number, t.disc_number,
                  t.duration_ms, t.bitrate, t.path, t.file_size,
                  t.album_id, al.title AS album_title, al.year,
                  t.artist_id, ar.name AS artist_name,
                  t.codec
             FROM tracks t
             LEFT JOIN albums  al ON al.id = t.album_id
             LEFT JOIN artists ar ON ar.id = t.artist_id
             $where
             $order},
        @args,
    )->hashes->to_array;
}

sub _playlist_row ($db, $playlist_id, $user_id) {
    return $db->query(
        q{SELECT p.id, p.name, p.description, p.is_public,
                 p.created_at, u.username,
                 (SELECT count(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) AS song_count,
                 (SELECT COALESCE(SUM(t.duration_ms), 0) / 1000
                    FROM playlist_tracks pt JOIN tracks t ON t.id = pt.track_id
                   WHERE pt.playlist_id = p.id) AS duration_sec
            FROM playlists p
            JOIN users u ON u.id = p.user_id
           WHERE p.id = ? AND (p.user_id = ? OR p.is_public = TRUE)},
        $playlist_id, $user_id,
    )->hash;
}

# ── playlists ────────────────────────────────────────────

sub get_playlists ($c) {
    my $uid = $c->stash('subsonic_user')->{id};
    my $rows = $c->pg->db->query(
        q{SELECT p.id, p.name, p.description, p.is_public,
                 p.created_at, u.username,
                 (SELECT count(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) AS song_count,
                 (SELECT COALESCE(SUM(t.duration_ms), 0) / 1000
                    FROM playlist_tracks pt JOIN tracks t ON t.id = pt.track_id
                   WHERE pt.playlist_id = p.id) AS duration_sec
            FROM playlists p
            JOIN users u ON u.id = p.user_id
           WHERE p.user_id = ? OR p.is_public = TRUE
           ORDER BY p.created_at DESC},
        $uid,
    )->hashes->to_array;

    $c->render(json => subsonic_response({
        playlists => {
            playlist => [ map { format_playlist($_) } @$rows ],
        },
    }));
}

sub get_playlist ($c) {
    my $id = id_value($c->param('id'));
    return $c->render(json => subsonic_error(70, 'Playlist not found'))
        unless $id;

    my $uid = $c->stash('subsonic_user')->{id};
    my $pl  = _playlist_row($c->pg->db, $id, $uid);
    return $c->render(json => subsonic_error(70, 'Playlist not found'))
        unless $pl;

    my $songs = _song_rows(
        $c->pg->db,
        'JOIN playlist_tracks pt ON pt.track_id = t.id WHERE pt.playlist_id = ?',
        'ORDER BY pt.position',
        $id,
    );

    my $fmt = format_playlist($pl);
    $fmt->{entry} = [ map { format_song($_) } @$songs ];

    $c->render(json => subsonic_response({ playlist => $fmt }));
}

sub create_playlist ($c) {
    my $uid  = $c->stash('subsonic_user')->{id};
    my $name = $c->param('name');
    return $c->render(json => subsonic_error(10, 'Playlist name required'))
        unless defined $name && length $name;

    my $pl = $c->pg->db->query(
        q{INSERT INTO playlists (user_id, name, is_public)
          VALUES (?, ?, ?)
          RETURNING id},
        $uid, $name, ($c->param('public') // '') eq 'true' ? 1 : 0,
    )->hash;

    # Collect songId — works whether the client sends one or many
    my @song_ids = @{ $c->every_param('songId') };
    @song_ids = grep { defined && length } @song_ids;

    my $pos = 1;
    for my $opaque (@song_ids) {
        my $tid = id_value($opaque);
        next unless $tid;
        $c->pg->db->query(
            q{INSERT INTO playlist_tracks (playlist_id, track_id, position)
              VALUES (?, ?, ?) ON CONFLICT DO NOTHING},
            $pl->{id}, $tid, $pos,
        );
        $pos++;
    }

    my $row = _playlist_row($c->pg->db, $pl->{id}, $uid);
    $c->render(json => subsonic_response({
        playlist => format_playlist($row),
    }));
}

sub update_playlist ($c) {
    my $id = id_value($c->param('playlistId'));
    return $c->render(json => subsonic_error(70, 'Playlist not found'))
        unless $id;

    my $uid = $c->stash('subsonic_user')->{id};
    my $pl = $c->pg->db->query(
        'SELECT id, user_id FROM playlists WHERE id = ?', $id,
    )->hash;
    return $c->render(json => subsonic_error(50, 'Not authorized'))
        unless $pl && $pl->{user_id} == $uid;

    my ($name, $comment, $public) = (
        $c->param('name'),
        $c->param('comment'),
        $c->param('public'),
    );
    $c->pg->db->query(
        q{UPDATE playlists
              SET name = COALESCE(?, name),
                  description = COALESCE(?, description),
                  is_public = COALESCE(?, is_public),
                  updated_at = now()
            WHERE id = ?},
        $name, $comment,
        (defined $public ? ($public eq 'true' ? 1 : 0) : undef),
        $id,
    );

    my @add_ids = @{ $c->every_param('songIdToAdd') };
    @add_ids = grep { defined && length } @add_ids;
    if (@add_ids) {
        my $next = $c->pg->db->query(
            'SELECT COALESCE(MAX(position), 0) + 1 AS p FROM playlist_tracks WHERE playlist_id = ?',
            $id,
        )->hash->{p};

        for my $opaque (@add_ids) {
            my $tid = id_value($opaque);
            next unless $tid;
            $c->pg->db->query(
                q{INSERT INTO playlist_tracks (playlist_id, track_id, position)
                  VALUES (?, ?, ?) ON CONFLICT DO NOTHING},
                $id, $tid, $next,
            );
            $next++;
        }
    }

    my @remove_idx = @{ $c->every_param('songIndexToRemove') };
    @remove_idx = grep { defined && /^\d+$/ } @remove_idx;
    if (@remove_idx) {
        my @ordered = $c->pg->db->query(
            'SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY position',
            $id,
        )->arrays->map(sub { $_->[0] })->to_array;

        my %to_remove = map { $_ => 1 } @remove_idx;
        for my $i (0 .. $#ordered) {
            next unless $to_remove{$i};
            $c->pg->db->query(
                'DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?',
                $id, $ordered[$i],
            );
        }

        my $pos = 1;
        for my $tid (@ordered) {
            next if $to_remove{ $pos - 1 };
            $c->pg->db->query(
                'UPDATE playlist_tracks SET position = ? WHERE playlist_id = ? AND track_id = ?',
                $pos, $id, $tid,
            );
            $pos++;
        }
    }

    $c->render(json => subsonic_response({}));
}

sub delete_playlist ($c) {
    my $id = id_value($c->param('id'));
    return $c->render(json => subsonic_error(70, 'Playlist not found'))
        unless $id;

    my $uid = $c->stash('subsonic_user')->{id};
    my $pl = $c->pg->db->query(
        'SELECT user_id FROM playlists WHERE id = ?', $id,
    )->hash;
    return $c->render(json => subsonic_error(50, 'Not authorized'))
        unless $pl && $pl->{user_id} == $uid;

    $c->pg->db->query('DELETE FROM playlists WHERE id = ?', $id);
    $c->render(json => subsonic_response({}));
}

# ── starred ──────────────────────────────────────────────

sub star   ($c) { _star_common($c, 1) }
sub unstar ($c) { _star_common($c, 0) }

sub _star_common ($c, $on) {
    my $uid = $c->stash('subsonic_user')->{id};
    my $db  = $c->pg->db;

    my @track_ids;

    my $id = $c->param('id');
    if (defined $id && length $id) {
        my $tid = id_value($id);
        push @track_ids, $tid if $tid;
    }

    my $album_id = $c->param('albumId');
    if (defined $album_id && length $album_id) {
        my $aid = id_value($album_id);
        if ($aid) {
            my $rows = $db->query(
                'SELECT id FROM tracks WHERE album_id = ?', $aid,
            )->arrays->map(sub { $_->[0] })->to_array;
            push @track_ids, @$rows;
        }
    }

    my $artist_id = $c->param('artistId');
    if (defined $artist_id && length $artist_id) {
        my $arid = id_value($artist_id);
        if ($arid) {
            my $rows = $db->query(
                'SELECT id FROM tracks WHERE artist_id = ?', $arid,
            )->arrays->map(sub { $_->[0] })->to_array;
            push @track_ids, @$rows;
        }
    }

    return $c->render(json => subsonic_error(10, 'Missing id'))
        unless @track_ids;

    for my $tid (@track_ids) {
        if ($on) {
            $db->query(
                'INSERT INTO favorites (user_id, track_id) VALUES (?, ?) ON CONFLICT DO NOTHING',
                $uid, $tid,
            );
        } else {
            $db->query(
                'DELETE FROM favorites WHERE user_id = ? AND track_id = ?',
                $uid, $tid,
            );
        }
    }

    $c->render(json => subsonic_response({}));
}

sub get_starred2 ($c) {
    my $uid = $c->stash('subsonic_user')->{id};

    my $songs = _song_rows(
        $c->pg->db,
        q{JOIN favorites f ON f.track_id = t.id WHERE f.user_id = ?},
        'ORDER BY f.created_at DESC',
        $uid,
    );

    $c->render(json => subsonic_response({
        starred2 => {
            song => [ map { format_song($_) } @$songs ],
        },
    }));
}

# ── scrobble ─────────────────────────────────────────────

sub scrobble ($c) {
    my $uid = $c->stash('subsonic_user')->{id};

    my @ids = @{ $c->every_param('id') };
    @ids = grep { defined && length } @ids;
    return $c->render(json => subsonic_response({})) unless @ids;

    my $submission = ($c->param('submission') // 'true') ne 'false';

    if ($submission) {
        for my $opaque (@ids) {
            my $tid = id_value($opaque);
            next unless $tid;
            $c->pg->db->query(
                'INSERT INTO user_plays (user_id, track_id) VALUES (?, ?)',
                $uid, $tid,
            );
        }
    }

    $c->render(json => subsonic_response({}));
}

# ── scanning ─────────────────────────────────────────────

sub get_scan_status ($c) {
    my $row = $c->pg->db->query(
        q{SELECT id, state, created, started, finished, notes
            FROM minion_jobs
           WHERE task = 'scan'
             AND state IN ('inactive', 'active')
           ORDER BY created DESC LIMIT 1},
    )->hash;

    my $scanning = $row ? \1 : \0;

    $c->render(json => subsonic_response({
        scanStatus => {
            scanning => $scanning,
            count    => 0,
            ($row && $row->{notes} ? (lastScan => $row->{notes}{processed}) : ()),
        },
    }));
}

sub start_scan ($c) {
    my $uid = $c->stash('subsonic_user')->{id};

    my $role = $c->pg->db->query('SELECT role FROM users WHERE id = ?', $uid)->hash;
    unless ($role && $role->{role} eq 'admin') {
        return $c->render(json => subsonic_error(50, 'Admin required'));
    }

    my $sp = $c->pg->db->query('SELECT id FROM scan_paths LIMIT 1')->hash;
    unless ($sp) {
        return $c->render(json => subsonic_response({
            scanStatus => { scanning => \0, count => 0 },
        }));
    }

    $c->minion->enqueue('scan' => [$sp->{id}]);

    $c->render(json => subsonic_response({
        scanStatus => { scanning => \1, count => 0 },
    }));
}

1;
