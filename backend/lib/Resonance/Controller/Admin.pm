package Resonance::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Auth qw(hash_password);
use Resonance::Util::Transcode qw(transcode_cache_stats clear_transcode_cache);

# ── users ────────────────────────────────────────────────

sub list_users ($c) {
    my $page     = $c->param('page')     // 1;
    my $per_page = $c->param('per_page') // 25;
    my $q        = $c->param('q');
    my $sort     = $c->param('sort')     // 'created_at';
    my $dir      = $c->param('dir')      // 'desc';

    $page     = 1    unless $page     =~ /^\d+$/ && $page     >= 1;
    $per_page = 25   unless $per_page =~ /^\d+$/;
    $per_page = 100  if $per_page > 100;
    $per_page = 1    if $per_page < 1;

    my %allowed_sort = map { $_ => 1 } qw/created_at username last_login_at role is_active/;
    $sort = 'created_at' unless $allowed_sort{$sort};
    $dir  = $dir eq 'asc' ? 'ASC' : 'DESC';

    my @where;
    my @args;

    if (defined $q && length $q) {
        push @where, '(username ILIKE ? OR email ILIKE ?)';
        push @args, "%$q%", "%$q%";
    }

    my $where_sql = @where ? 'WHERE ' . join(' AND ', @where) : '';

    my $total = $c->pg->db->query(
        "SELECT count(*) AS n FROM users $where_sql",
        @args,
    )->hash->{n} + 0;

    my $offset = ($page - 1) * $per_page;

    # Whitelist as safe SQL fragment — sort and dir are validated above
    my $order_sql = "ORDER BY $sort $dir";

    my $users = $c->pg->db->query(
        qq{SELECT id, username, email, role, is_active,
                  created_at, last_login_at
             FROM users
             $where_sql
             $order_sql
             LIMIT ? OFFSET ?},
        @args, $per_page, $offset,
    )->hashes->to_array;

    $c->render(json => {
        users    => $users,
        total    => $total,
        page     => $page,
        per_page => $per_page,
        sort     => $sort,
        dir      => lc $dir,
    });
}

sub create_user ($c) {
    my $body = $c->req->json // {};
    my ($u, $p) = ($body->{username}, $body->{password});

    return $c->render(status => 400, json => { error => 'username_required' })
        unless defined $u && length $u;
    return $c->render(status => 400, json => { error => 'username_invalid' })
        unless $u =~ /^\w{3,64}$/;
    return $c->render(status => 400, json => { error => 'password_too_short' })
        unless defined $p && length($p) >= 8;

    my $role = ($body->{role} // 'user') eq 'admin' ? 'admin' : 'user';

    my $row = eval {
        $c->pg->db->query(
            q{INSERT INTO users (username, email, password_hash, role)
              VALUES (?, ?, ?, ?)
          RETURNING id, username, email, role, is_active, created_at, last_login_at},
            $u, $body->{email}, hash_password($p), $role,
        )->hash;
    };

    return $c->render(status => 409, json => { error => 'username_taken' })
        unless $row;

    $c->render(status => 201, json => { user => $row });
}

sub update_user ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    my $body = $c->req->json // {};

    if ($id == $c->stash('current_user_id')) {
        if (exists $body->{role} && $body->{role} ne 'admin') {
            return $c->render(status => 400, json => { error => 'cannot_demote_self' });
        }
        if (exists $body->{is_active} && !$body->{is_active}) {
            return $c->render(status => 400, json => { error => 'cannot_deactivate_self' });
        }
    }

    my $new_role = $body->{role};
    $new_role = 'user' if defined $new_role && $new_role ne 'admin' && $new_role ne 'user';

    my $row = $c->pg->db->query(
        q{UPDATE users
              SET role      = COALESCE(?, role),
                  is_active = COALESCE(?, is_active),
                  email     = COALESCE(?, email),
                  updated_at = now()
            WHERE id = ?
        RETURNING id, username, email, role, is_active, created_at, last_login_at},
        $new_role,
        exists $body->{is_active} ? ($body->{is_active} ? 1 : 0) : undef,
        $body->{email},
        $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'user_not_found' })
        unless $row;

    $c->render(json => { user => $row });
}

sub delete_user ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless $id =~ /^\d+$/;

    if ($id == $c->stash('current_user_id')) {
        return $c->render(status => 400, json => { error => 'cannot_delete_self' });
    }

    my $n = $c->pg->db->query('DELETE FROM users WHERE id = ?', $id)->rows;
    return $c->render(status => 404, json => { error => 'user_not_found' })
        unless $n;

    $c->render(json => { ok => \1 });
}

# ── stats ────────────────────────────────────────────────

sub stats ($c) {
    my $db = $c->pg->db;

    my $counts = $db->query(
        q{SELECT
            (SELECT count(*) FROM users)   AS users,
            (SELECT count(*) FROM artists) AS artists,
            (SELECT count(*) FROM albums)  AS albums,
            (SELECT count(*) FROM tracks)  AS tracks,
            (SELECT count(*) FROM playlists) AS playlists},
    )->hash;

    my $recent = $db->query(
        q{SELECT p.id, p.played_at,
                 u.username,
                 t.title AS track_title,
                 ar.name AS artist_name
            FROM user_plays p
            JOIN users   u  ON u.id  = p.user_id
            JOIN tracks  t  ON t.id  = p.track_id
            LEFT JOIN artists ar ON ar.id = t.artist_id
           ORDER BY p.played_at DESC
           LIMIT 20},
    )->hashes->to_array;

    my $scans = $db->query(
        q{SELECT id, path, last_scan_at FROM scan_paths ORDER BY id},
    )->hashes->to_array;

    $c->render(json => {
        counts => $counts,
        recent_plays => $recent,
        scan_paths => $scans,
    });
}

sub transcode_stats ($c) {
    $c->render(json => { cache => transcode_cache_stats($c->app) });
}

sub transcode_clear ($c) {
    my $removed = clear_transcode_cache($c->app);
    $c->render(json => { ok => \1, removed => $removed });
}

1;
