package Resonance::Controller::Me;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Auth qw(generate_device_token hash_token);
use Resonance::Subsonic::Auth qw(encrypt_subsonic_password);

sub show ($c) {
    my $user = $c->pg->db->query(
        'SELECT id, username, email, role, created_at, last_login_at
           FROM users WHERE id = ?',
        $c->stash('current_user_id'),
    )->hash;

    return $c->render(status => 404, json => { error => 'user_not_found' })
        unless $user;

    $c->render(json => { user => $user });
}

sub list_tokens ($c) {
    my $rows = $c->pg->db->query(
        q{SELECT id, name, scopes, last_used_at, expires_at, created_at
          FROM api_tokens WHERE user_id = ? ORDER BY created_at DESC},
        $c->stash('current_user_id'),
    )->hashes->to_array;

    $c->render(json => { tokens => $rows });
}

sub create_token ($c) {
    my $body = $c->req->json // {};
    my $name = $body->{name} // 'unnamed';

    my $plain = generate_device_token();
    my $row = $c->pg->db->query(
        q{INSERT INTO api_tokens (user_id, name, token_hash, scopes)
          VALUES (?, ?, ?, ?)
          RETURNING id, name, scopes, created_at},
        $c->stash('current_user_id'),
        $name,
        hash_token($plain),
        $body->{scopes} // ['read'],
    )->hash;

    # Plain token is returned ONCE — never stored
    $c->render(status => 201, json => {
        token  => $plain,
        record => $row,
        warning => 'Store this token now. It will not be shown again.',
    });
}

sub delete_token ($c) {
    my $id = $c->param('id');
    my $n = $c->pg->db->query(
        'DELETE FROM api_tokens WHERE id = ? AND user_id = ?',
        $id, $c->stash('current_user_id'),
    )->rows;

    return $c->render(status => 404, json => { error => 'not_found' })
        unless $n;

    $c->render(json => { ok => \1 });
}

sub trigger_scan ($c) {
    my $body = $c->req->json // {};
    my $path = $body->{path} // $c->config->{media_root};

    unless ($path && -d $path) {
        return $c->render(status => 400, json => { error => 'invalid_path' });
    }

    # Upsert scan_path
    my $sp = $c->pg->db->query(
        q{INSERT INTO scan_paths (path) VALUES (?)
          ON CONFLICT (path) DO UPDATE SET path = EXCLUDED.path
          RETURNING id},
        $path,
    )->hash;

    my $job_id = $c->minion->enqueue('scan' => [$sp->{id}]);

    $c->render(json => { job_id => $job_id, scan_path_id => $sp->{id} });
}

sub set_subsonic_password ($c) {
    my $body = $c->req->json // {};
    my $pw   = $body->{subsonic_password};

    # Allow clearing
    if (!defined $pw || $pw eq '') {
        $c->pg->db->query(
            'UPDATE users SET subsonic_password_enc = NULL WHERE id = ?',
            $c->stash('current_user_id'),
        );
        return $c->render(json => { ok => \1, configured => \0 });
    }

    if (length($pw) < 8) {
        return $c->render(status => 400, json => { error => 'password_too_short' });
    }

    my $enc = encrypt_subsonic_password($c->config->{jwt}{secret}, $pw);

    $c->pg->db->query(
        'UPDATE users SET subsonic_password_enc = ? WHERE id = ?',
        $enc, $c->stash('current_user_id'),
    );

    $c->render(json => { ok => \1, configured => \1 });
}

sub subsonic_status ($c) {
    my $configured = $c->pg->db->query(
        'SELECT subsonic_password_enc IS NOT NULL AS c FROM users WHERE id = ?',
        $c->stash('current_user_id'),
    )->hash->{c};

    $c->render(json => { configured => $configured ? \1 : \0 });
}

1;
