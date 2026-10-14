package Resonance::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Auth qw(
    hash_password verify_password
    issue_access_token generate_refresh_token hash_token
);

# ── helpers ──────────────────────────────────────────────

sub _issue_tokens ($c, $user_id) {
    my $jwt = $c->config->{jwt};

    my $access_ttl  = $jwt->{access_ttl}  // 900;
    my $refresh_ttl = $jwt->{refresh_ttl} // 2_592_000;

    my $access  = issue_access_token($jwt->{secret}, $user_id, $access_ttl);
    my $refresh = generate_refresh_token();

    $c->pg->db->query(
        q{INSERT INTO refresh_tokens
              (user_id, token_hash, expires_at, user_agent, ip_address)
          VALUES (?, ?, now() + make_interval(secs => ?), ?, ?)},
        $user_id,
        hash_token($refresh),
        $refresh_ttl,
        $c->req->headers->user_agent,
        $c->tx->remote_address,
    );

    return ($access, $refresh, $access_ttl);
}

# ── endpoints ────────────────────────────────────────────

sub register ($c) {
    return $c->render(status => 403, json => { error => 'registration_disabled' })
        unless $c->config->{allow_registration};

    my $body = $c->req->json // {};
    my ($u, $p) = ($body->{username}, $body->{password});
    my $e = $body->{email};

    return $c->render(status => 400, json => { error => 'username_required' })
        unless defined $u && length $u;
    return $c->render(status => 400, json => { error => 'password_too_short' })
        unless defined $p && length($p) >= 8;

    my $hash = hash_password($p);

    my $row = eval {
        $c->pg->db->query(
            'INSERT INTO users (username, email, password_hash)
             VALUES (?, ?, ?) RETURNING id, username',
            $u, $e, $hash,
        )->hash;
    };
    return $c->render(status => 409, json => { error => 'username_taken' })
        unless $row;

    my ($access, $refresh, $ttl) = _issue_tokens($c, $row->{id});

    $c->render(json => {
        user          => { id => 0 + $row->{id}, username => $row->{username} },
        access_token  => $access,
        refresh_token => $refresh,
        expires_in    => $ttl,
    });
}

sub login ($c) {
    my $body = $c->req->json // {};
    my ($u, $p) = ($body->{username}, $body->{password});

    return $c->render(status => 400, json => { error => 'missing_credentials' })
        unless defined $u && defined $p;

    my $user = $c->pg->db->query(
        'SELECT id, username, password_hash, is_active
           FROM users WHERE lower(username) = lower(?)',
        $u,
    )->hash;

    # Always verify, even when user is missing, to reduce timing leak
    my $hash = $user ? $user->{password_hash}
                     : hash_password('dummy-password-for-timing');
    my $ok = verify_password($hash, $p);

    return $c->render(status => 401, json => { error => 'invalid_credentials' })
        unless $user && $ok && $user->{is_active};

    my ($access, $refresh, $ttl) = _issue_tokens($c, $user->{id});

    $c->render(json => {
        user          => { id => 0 + $user->{id}, username => $user->{username} },
        access_token  => $access,
        refresh_token => $refresh,
        expires_in    => $ttl,
    });
}

sub refresh ($c) {
    my $body = $c->req->json // {};
    my $rt = $body->{refresh_token};
    return $c->render(status => 400, json => { error => 'missing_refresh_token' })
        unless defined $rt && length $rt;

    my $hash = hash_token($rt);

    # Atomically: lock the row, revoke it, hand back the user_id
    my $row = eval {
        my $db  = $c->pg->db;
        my $tok = $db->query(
            q{SELECT id, user_id FROM refresh_tokens
               WHERE token_hash = ?
                 AND revoked_at IS NULL
                 AND expires_at > now()
               FOR UPDATE},
            $hash,
        )->hash;
        die "not_found\n" unless $tok;

        $db->query(
            'UPDATE refresh_tokens SET revoked_at = now() WHERE id = ?',
            $tok->{id},
        );
        $tok;
    };
    return $c->render(status => 401, json => { error => 'invalid_refresh_token' })
        unless $row;

    my ($access, $new_refresh, $ttl) = _issue_tokens($c, $row->{user_id});

    $c->render(json => {
        access_token  => $access,
        refresh_token => $new_refresh,
        expires_in    => $ttl,
    });
}

sub logout ($c) {
    my $body = $c->req->json // {};
    my $rt = $body->{refresh_token};

    if (defined $rt && length $rt) {
        $c->pg->db->query(
            'UPDATE refresh_tokens SET revoked_at = now()
              WHERE token_hash = ? AND revoked_at IS NULL',
            hash_token($rt),
        );
    }
    else {
        $c->pg->db->query(
            'UPDATE refresh_tokens SET revoked_at = now()
              WHERE user_id = ? AND revoked_at IS NULL',
            $c->stash('current_user_id'),
        );
    }

    $c->render(json => { ok => \1 });
}

1;
