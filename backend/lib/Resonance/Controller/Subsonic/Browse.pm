package Resonance::Controller::Subsonic::Browse;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    get_indexes get_artists get_artist get_album get_song
    get_artist_info2 get_album_info2 get_genres
    get_album_list2 get_album_list get_random_songs
    get_songs_by_genre search3
);

use Resonance::Subsonic::Format qw(
    subsonic_response subsonic_error
    id_for id_type id_value
    format_artist format_album format_song format_indexes
);

# ── helpers ──────────────────────────────────────────────

sub _clamp ($v, $min, $max) {
    return $min unless defined $v && $v =~ /^\d+$/;
    return $min if $v < $min;
    return $max if $v > $max;
    return 0 + $v;
}

sub _album_rows ($db, $where = '', $order = '', @args) {
    return $db->query(
        qq{SELECT a.id, a.title, a.year, a.artist_id, ar.name AS artist_name,
                  a.created_at,
                  (SELECT count(*) FROM tracks t WHERE t.album_id = a.id) AS song_count,
                  (SELECT COALESCE(SUM(duration_ms), 0) / 1000
                     FROM tracks t WHERE t.album_id = a.id) AS duration_sec
             FROM albums a
             LEFT JOIN artists ar ON ar.id = a.artist_id
             $where
             $order},
        @args,
    )->hashes->to_array;
}

sub _song_rows ($db, $where = '', $order = '', @args) {
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

# ── indexes & artists ────────────────────────────────────

sub get_indexes ($c) {
    my $artists = $c->pg->db->query(
        q{SELECT id, name, sort_name FROM artists
           ORDER BY COALESCE(sort_name, name)},
    )->hashes->to_array;

    $c->render(json => subsonic_response(format_indexes($artists)));
}

sub get_artists ($c) {
    my $artists = $c->pg->db->query(
        q{SELECT ar.id, ar.name, ar.sort_name,
                 (SELECT count(*) FROM albums al WHERE al.artist_id = ar.id) AS album_count,
                 (SELECT MIN(al.id) FROM albums al WHERE al.artist_id = ar.id) AS cover_album_id
            FROM artists ar
           ORDER BY COALESCE(ar.sort_name, ar.name)},
    )->hashes->to_array;

    my @formatted = map { format_artist($_) } @$artists;

    # Group by first letter for the modern getArtists shape
    my %by_letter;
    for my $i (0 .. $#$artists) {
        my $first = uc substr($artists->[$i]{sort_name} // $artists->[$i]{name} // '?', 0, 1);
        $first = '#' unless $first =~ /^[A-Z]$/;
        push @{ $by_letter{$first} }, $formatted[$i];
    }

    my @indexes;
    for my $letter (sort keys %by_letter) {
        push @indexes, {
            name   => $letter,
            artist => $by_letter{$letter},
        };
    }

    $c->render(json => subsonic_response({
        artists => {
            ignoredArticles => 'The El La Los Las Le Les',
            index           => \@indexes,
        },
    }));
}

sub get_artist ($c) {
    my $id = id_value($c->param('id'));
    return $c->render(json => subsonic_error(70, 'Artist not found'))
        unless $id;

    my $artist = $c->pg->db->query(
        'SELECT id, name FROM artists WHERE id = ?', $id,
    )->hash;
    return $c->render(json => subsonic_error(70, 'Artist not found'))
        unless $artist;

    my $albums = _album_rows($c->pg->db, 'WHERE a.artist_id = ?', 'ORDER BY a.year NULLS LAST, a.title', $id);

    $c->render(json => subsonic_response({
        artist => {
            id         => id_for('ar', $artist->{id}),
            name       => $artist->{name},
            albumCount => scalar @$albums,
            album      => [ map { format_album($_) } @$albums ],
        },
    }));
}

# ── albums ───────────────────────────────────────────────

sub get_album ($c) {
    my $id = id_value($c->param('id'));
    return $c->render(json => subsonic_error(70, 'Album not found'))
        unless $id;

    my $albums = _album_rows($c->pg->db, 'WHERE a.id = ?', '', $id);
    return $c->render(json => subsonic_error(70, 'Album not found'))
        unless @$albums;

    my $songs = _song_rows(
        $c->pg->db,
        'WHERE t.album_id = ?',
        'ORDER BY t.disc_number NULLS FIRST, t.track_number NULLS FIRST, t.title',
        $id,
    );

    my $album = format_album($albums->[0]);
    $album->{song} = [ map { format_song($_) } @$songs ];

    $c->render(json => subsonic_response({ album => $album }));
}

sub get_album_list2 ($c) { _album_list($c, 'albumList2') }
sub get_album_list  ($c) { _album_list($c, 'albumList') }

sub _album_list ($c, $wrapper) {
    my $type   = $c->param('type')   // 'newest';
    my $size   = _clamp($c->param('size'),   1, 500);
    my $offset = _clamp($c->param('offset'), 0, 100_000);
    $size = 50 unless defined $c->param('size');

    my ($where, $order, @args) = ('', '', ());

    if ($type eq 'newest') {
        $order = 'ORDER BY a.created_at DESC NULLS LAST, a.id DESC';
    }
    elsif ($type eq 'recent') {
        $order = 'ORDER BY a.updated_at DESC NULLS LAST, a.id DESC';
    }
    elsif ($type eq 'frequent') {
        # Not tracking play count per album yet; fall back to newest
        $order = 'ORDER BY a.created_at DESC NULLS LAST, a.id DESC';
    }
    elsif ($type eq 'alphabeticalByName') {
        $order = 'ORDER BY a.title';
    }
    elsif ($type eq 'alphabeticalByArtist') {
        $order = 'ORDER BY ar.name NULLS LAST, a.year NULLS LAST, a.title';
    }
    elsif ($type eq 'random') {
        $order = 'ORDER BY random()';
    }
    elsif ($type eq 'byYear') {
        my ($from, $to) = ($c->param('fromYear'), $c->param('toYear'));
        if (defined $from && $from =~ /^\d+$/ && defined $to && $to =~ /^\d+$/) {
            $where = 'WHERE a.year BETWEEN ? AND ?';
            @args = ($from, $to);
        }
        $order = 'ORDER BY a.year DESC NULLS LAST, a.title';
    }
    elsif ($type eq 'starred') {
        # Implemented in 13b-3
        return $c->render(json => subsonic_response({ $wrapper => { album => [] } }));
    }
    else {
        $order = 'ORDER BY a.title';
    }

    my $albums = _album_rows(
        $c->pg->db,
        $where,
        "$order LIMIT ? OFFSET ?",
        @args, $size, $offset,
    );

    $c->render(json => subsonic_response({
        $wrapper => {
            album => [ map { format_album($_) } @$albums ],
        },
    }));
}

# ── songs ────────────────────────────────────────────────

sub get_song ($c) {
    my $id = id_value($c->param('id'));
    return $c->render(json => subsonic_error(70, 'Song not found'))
        unless $id;

    my $songs = _song_rows($c->pg->db, 'WHERE t.id = ?', '', $id);
    return $c->render(json => subsonic_error(70, 'Song not found'))
        unless @$songs;

    $c->render(json => subsonic_response({ song => format_song($songs->[0]) }));
}

sub get_random_songs ($c) {
    my $size = _clamp($c->param('size'), 1, 500);
    $size = 50 unless defined $c->param('size');

    my ($where, @args) = ('', ());
    my $genre = $c->param('genre');

    if (defined($genre) && length $genre) {
        # Genre filtering arrives with a join in 13b-3; return random for now
    }

    my $songs = _song_rows(
        $c->pg->db,
        $where,
        'ORDER BY random() LIMIT ?',
        @args, $size,
    );

    $c->render(json => subsonic_response({
        randomSongs => {
            song => [ map { format_song($_) } @$songs ],
        },
    }));
}

sub get_songs_by_genre ($c) {
    # Genre indexing not built yet — return empty
    $c->render(json => subsonic_response({
        songsByGenre => { song => [] },
    }));
}

# ── genres & info stubs ──────────────────────────────────

sub get_genres ($c) {
    $c->render(json => subsonic_response({ genres => { genre => [] } }));
}

sub get_artist_info2 ($c) {
    $c->render(json => subsonic_response({
        artistInfo2 => {
            biography      => '',
            musicBrainzId  => '',
            smallImageUrl  => '',
            mediumImageUrl => '',
            largeImageUrl  => '',
            similarArtist  => [],
        },
    }));
}

sub get_album_info2 ($c) {
    $c->render(json => subsonic_response({
        albumInfo => {
            notes          => '',
            musicBrainzId  => '',
            smallImageUrl  => '',
            mediumImageUrl => '',
            largeImageUrl  => '',
        },
    }));
}

# ── search ───────────────────────────────────────────────

sub search3 ($c) {
    my $q = $c->param('query') // '';

    my $artist_count = _clamp($c->param('artistCount'), 0, 100);
    my $album_count  = _clamp($c->param('albumCount'),  0, 100);
    my $song_count   = _clamp($c->param('songCount'),   0, 100);
    $artist_count ||= 20 if !defined $c->param('artistCount');
    $album_count  ||= 20 if !defined $c->param('albumCount');
    $song_count   ||= 50 if !defined $c->param('songCount');

    my $db = $c->pg->db;

    my ($artists, $albums, $songs) = ([], [], []);

    if (!length $q) {
        # Empty query = random picks per spec
        $artists = $db->query(
            'SELECT id, name FROM artists ORDER BY random() LIMIT ?',
            $artist_count,
        )->hashes->to_array;
        $albums = _album_rows($db, '', 'ORDER BY random() LIMIT ?', $album_count);
        $songs  = _song_rows($db, '', 'ORDER BY random() LIMIT ?', $song_count);
    }
    else {
        my $like = "%$q%";

        $artists = $db->query(
            q{SELECT id, name FROM artists
               WHERE name ILIKE ?
               ORDER BY similarity(lower(name), lower(?)) DESC NULLS LAST, name
               LIMIT ?},
            $like, $q, $artist_count,
        )->hashes->to_array;

        $albums = _album_rows(
            $db,
            'WHERE a.title ILIKE ?',
            'ORDER BY similarity(lower(a.title), lower(?)) DESC NULLS LAST, a.title LIMIT ?',
            $like, $q, $album_count,
        );

        $songs = _song_rows(
            $db,
            q{WHERE t.search_tsv @@ plainto_tsquery('simple', ?)
                 OR t.title ILIKE ?},
            q{ORDER BY ts_rank(t.search_tsv, plainto_tsquery('simple', ?)) DESC NULLS LAST, t.title
               LIMIT ?},
            $q, $like, $q, $song_count,
        );
    }

    $c->render(json => subsonic_response({
        searchResult3 => {
            artist => [ map { format_artist($_) } @$artists ],
            album  => [ map { format_album($_) }  @$albums  ],
            song   => [ map { format_song($_) }   @$songs   ],
        },
    }));
}

1;
