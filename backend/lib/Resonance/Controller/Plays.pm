package Resonance::Controller::Plays;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub log_play ($c) {
    my $id = $c->param('track_id');
    return $c->render(status => 400, json => { error => 'invalid_id' })
        unless defined $id && $id =~ /^\d+$/;

    my $exists = $c->pg->db->query(
        'SELECT 1 FROM tracks WHERE id = ?', $id,
    )->array;

    return $c->render(status => 404, json => { error => 'track_not_found' })
        unless $exists;

    $c->pg->db->query(
        'INSERT INTO user_plays (user_id, track_id) VALUES (?, ?)',
        $c->stash('current_user_id'), $id,
    );

    $c->render(json => { ok => \1 });
}

1;
