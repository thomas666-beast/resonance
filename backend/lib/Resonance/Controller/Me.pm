package Resonance::Controller::Me;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Auth qw(generate_device_token hash_token);

sub show ($c) {
    my $user = $c->pg->db->query(
        'SELECT id, username, email, role, created_at FROM users WHERE id = ?',
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

1;
