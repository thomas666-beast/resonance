package Resonance::Controller::Library;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# ── helpers ──────────────────────────────────────────────

sub _paginate ($c) {
    my $limit  = $c->param('limit')  // 50;
    my $offset = $c->param('offset') // 0;
    $limit  = 50  unless $limit  =~ /^\d+$/;
    $offset = 0   unless $offset =~ /^\d+$/;
    $limit  = 200 if $limit > 200;
    return ($limit + 0, $offset + 0);
}

# ── artists ──────────────────────────────────────────────

sub artists ($c) {
    my ($limit, $offset) = _paginate($c);
    my $q = $c->param('q');

    my ($sql, @args);
    if (defined $q && length $q) {
        $sql = q{SELECT id, name, sort_name, image_path
                   FROM artists
                  WHERE name ILIKE ? OR sort_name ILIKE ?
                  ORDER BY coalesce(sort_name, name)
                  LIMIT ? OFFSET ?};
        @args = ("%$q%", "%$q%", $limit, $offset);
    }
    else {
        $sql = q{SELECT id, name, sort_name, image_path
                   FROM artists
                  ORDER BY coalesce(sort_name, name)
                  LIMIT ? OFFSET ?};
        @args = ($limit, $offset);
    }

    my $rows = $c->pg->db->query($sql, @args)->hashes->to_array;
    $c->render(json => { artists => $rows, limit => $limit, offset => $offset });
}

sub artist_detail ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $artist = $c->pg->db->query(
        q{SELECT id, name, sort_name, mb_id, image_path, bio
            FROM artists WHERE id = ?},
        $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'artist_not_found' })
        unless $artist;

    # Only show top-level albums on the artist page;
    # sub-albums surface inside the parent album's detail view.
    my $albums = $c->pg->db->query(
        q{SELECT id, title, year, cover_path, parent_id
            FROM albums
           WHERE artist_id = ? AND parent_id IS NULL
           ORDER BY year NULLS LAST, title},
        $id,
    )->hashes->to_array;

    $c->render(json => { artist => $artist, albums => $albums });
}

# ── albums ───────────────────────────────────────────────

sub albums ($c) {
    my ($limit, $offset) = _paginate($c);
    my $q          = $c->param('q');
    my $artist_id  = $c->param('artist_id');
    my $include_children = $c->param('include_children') ? 1 : 0;

    my @where;
    my @args;

    unless ($include_children) {
        push @where, 'a.parent_id IS NULL';
    }

    if (defined $q && length $q) {
        push @where, 'a.title ILIKE ?';
        push @args, "%$q%";
    }
    if (defined $artist_id && $artist_id =~ /^\d+$/) {
        push @where, 'a.artist_id = ?';
        push @args, $artist_id;
    }

    my $where = @where ? 'WHERE ' . join(' AND ', @where) : '';

    my $rows = $c->pg->db->query(
        qq{SELECT a.id, a.title, a.year, a.cover_path,
                  a.artist_id, ar.name AS artist_name,
                  a.parent_id,
                  (SELECT count(*) FROM tracks t WHERE t.album_id = a.id) AS track_count,
                  (SELECT count(*) FROM albums c WHERE c.parent_id = a.id) AS child_count
             FROM albums a
             LEFT JOIN artists ar ON ar.id = a.artist_id
             $where
             ORDER BY a.year DESC NULLS LAST, a.title
             LIMIT ? OFFSET ?},
        @args, $limit, $offset,
    )->hashes->to_array;

    $c->render(json => { albums => $rows, limit => $limit, offset => $offset });
}

sub album_detail ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $album = $c->pg->db->query(
        q{SELECT a.id, a.title, a.year, a.cover_path,
                 a.artist_id, ar.name AS artist_name,
                 a.parent_id,
                 p.title AS parent_title
            FROM albums a
            LEFT JOIN artists ar ON ar.id = a.artist_id
            LEFT JOIN albums p  ON p.id  = a.parent_id
           WHERE a.id = ?},
        $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'album_not_found' })
        unless $album;

    # Tracks belonging directly to this album
    my $tracks = $c->pg->db->query(
        q{SELECT id, title, track_number, disc_number,
                 duration_ms, bitrate, sample_rate, channels, codec,
                 album_id, artist_id
            FROM tracks
           WHERE album_id = ?
           ORDER BY disc_number NULLS FIRST, track_number NULLS FIRST, title},
        $id,
    )->hashes->to_array;

    for my $t (@$tracks) {
        $t->{album_title} = $album->{title};
        $t->{artist_name} = $album->{artist_name};
    }

    # Sub-albums nested under this album, with their tracks preloaded
    my $children = $c->pg->db->query(
        q{SELECT a.id, a.title, a.year, a.cover_path, a.parent_id,
                 (SELECT count(*) FROM tracks t WHERE t.album_id = a.id) AS track_count,
                 (SELECT COALESCE(SUM(t.duration_ms), 0)
                    FROM tracks t WHERE t.album_id = a.id) AS duration_ms
            FROM albums a
           WHERE a.parent_id = ?
           ORDER BY a.year NULLS LAST, a.title},
        $id,
    )->hashes->to_array;

    for my $child (@$children) {
        my $child_tracks = $c->pg->db->query(
            q{SELECT id, title, track_number, disc_number,
                     duration_ms, bitrate, sample_rate, channels, codec,
                     album_id, artist_id
                FROM tracks
               WHERE album_id = ?
               ORDER BY disc_number NULLS FIRST, track_number NULLS FIRST, title},
            $child->{id},
        )->hashes->to_array;

        for my $t (@$child_tracks) {
            $t->{album_title} = $child->{title};
            $t->{artist_name} = $album->{artist_name};
        }

        $child->{tracks} = $child_tracks;
    }

    $c->render(json => {
        album    => $album,
        tracks   => $tracks,
        children => $children,
    });
}

# ── tracks ───────────────────────────────────────────────

sub track_detail ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $track = $c->pg->db->query(
        q{SELECT t.id, t.title, t.track_number, t.disc_number,
                 t.duration_ms, t.bitrate, t.sample_rate, t.channels,
                 t.codec, t.file_size, t.path,
                 t.album_id, al.title AS album_title,
                 t.artist_id, ar.name AS artist_name
            FROM tracks t
            LEFT JOIN albums  al ON al.id = t.album_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           WHERE t.id = ?},
        $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'track_not_found' })
        unless $track;

    delete $track->{path};

    $c->render(json => { track => $track });
}

1;
