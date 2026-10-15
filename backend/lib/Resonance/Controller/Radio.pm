package Resonance::Controller::Radio;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# ── helpers ──────────────────────────────────────────────

sub _load_station ($c, $id) {
    return $c->pg->db->query(
        q{SELECT id, name, stream_url, homepage_url, logo_url,
                 genre, bitrate, is_public, created_by,
                 created_at, updated_at
            FROM radio_stations
           WHERE id = ?},
        $id,
    )->hash;
}

sub _is_admin ($c) {
    my $row = $c->pg->db->query(
        'SELECT role FROM users WHERE id = ?',
        $c->stash('current_user_id'),
    )->hash;
    return $row && $row->{role} eq 'admin';
}

# ── endpoints ────────────────────────────────────────────

sub list ($c) {
    my $uid    = $c->stash('current_user_id');
    my $admin  = _is_admin($c);

    # Admins see everything; regular users see public stations only
    my $rows = $admin
        ? $c->pg->db->query(
            q{SELECT id, name, stream_url, homepage_url, logo_url,
                     genre, bitrate, is_public, created_by,
                     created_at, updated_at
                FROM radio_stations
               ORDER BY lower(name)},
        )->hashes->to_array
        : $c->pg->db->query(
            q{SELECT id, name, stream_url, homepage_url, logo_url,
                     genre, bitrate, is_public, created_by,
                     created_at, updated_at
                FROM radio_stations
               WHERE is_public = TRUE
               ORDER BY lower(name)},
        )->hashes->to_array;

    $c->render(json => {
        stations => $rows,
        is_admin => $admin ? \1 : \0,
    });
}

sub show ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $station = _load_station($c, $id);
    return $c->render(status => 404, json => { error => 'station_not_found' })
        unless $station;

    # Non-admin can't see private stations
    unless ($station->{is_public} || _is_admin($c)) {
        return $c->render(status => 404, json => { error => 'station_not_found' });
    }

    $c->render(json => { station => $station });
}

sub create ($c) {
    return $c->render(status => 403, json => { error => 'admin_required' })
        unless _is_admin($c);

    my $body = $c->req->json // {};
    my $name = $body->{name};
    my $url  = $body->{stream_url};

    return $c->render(status => 400, json => { error => 'name_required' })
        unless defined $name && length $name;
    return $c->render(status => 400, json => { error => 'stream_url_required' })
        unless defined $url && length $url;

    # Sanity-check the URL. Only http(s).
    return $c->render(status => 400, json => { error => 'invalid_stream_url' })
        unless $url =~ m{^https?://};

    my $row = $c->pg->db->query(
        q{INSERT INTO radio_stations
              (name, stream_url, homepage_url, logo_url, genre, bitrate,
               is_public, created_by)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          RETURNING id, name, stream_url, homepage_url, logo_url,
                    genre, bitrate, is_public, created_by,
                    created_at, updated_at},
        $name,
        $url,
        $body->{homepage_url},
        $body->{logo_url},
        $body->{genre},
        (defined $body->{bitrate} && $body->{bitrate} =~ /^\d+$/)
            ? $body->{bitrate} : undef,
        exists $body->{is_public}
            ? ($body->{is_public} ? 1 : 0)
            : 1,
        $c->stash('current_user_id'),
    )->hash;

    $c->render(status => 201, json => { station => $row });
}

sub update ($c) {
    return $c->render(status => 403, json => { error => 'admin_required' })
        unless _is_admin($c);

    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $existing = _load_station($c, $id);
    return $c->render(status => 404, json => { error => 'station_not_found' })
        unless $existing;

    my $body = $c->req->json // {};

    my $url = $body->{stream_url};
    if (defined $url && length $url && $url !~ m{^https?://}) {
        return $c->render(status => 400, json => { error => 'invalid_stream_url' });
    }

    my $row = $c->pg->db->query(
        q{UPDATE radio_stations
              SET name         = COALESCE(?, name),
                  stream_url   = COALESCE(?, stream_url),
                  homepage_url = COALESCE(?, homepage_url),
                  logo_url     = COALESCE(?, logo_url),
                  genre        = COALESCE(?, genre),
                  bitrate      = COALESCE(?, bitrate),
                  is_public    = COALESCE(?, is_public),
                  updated_at   = now()
            WHERE id = ?
        RETURNING id, name, stream_url, homepage_url, logo_url,
                  genre, bitrate, is_public, created_by,
                  created_at, updated_at},
        (defined $body->{name} && length $body->{name}) ? $body->{name} : undef,
        (defined $url && length $url) ? $url : undef,
        $body->{homepage_url},
        $body->{logo_url},
        $body->{genre},
        (defined $body->{bitrate} && $body->{bitrate} =~ /^\d+$/)
            ? $body->{bitrate} : undef,
        exists $body->{is_public} ? ($body->{is_public} ? 1 : 0) : undef,
        $id,
    )->hash;

    $c->render(json => { station => $row });
}

sub remove ($c) {
    return $c->render(status => 403, json => { error => 'admin_required' })
        unless _is_admin($c);

    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $n = $c->pg->db->query(
        'DELETE FROM radio_stations WHERE id = ?', $id,
    )->rows;

    return $c->render(status => 404, json => { error => 'station_not_found' })
        unless $n;

    $c->render(json => { ok => \1 });
}

1;
