package Resonance::Plugin::Admin;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {
    $app->routes->add_shortcut(admin_required => sub ($r) {
        return $r->under(sub ($c) {
            my $uid = $c->stash('current_user_id');
            unless ($uid) {
                $c->render(status => 401, json => { error => 'unauthenticated' });
                return;
            }

            my $role = $c->pg->db->query(
                'SELECT role FROM users WHERE id = ?', $uid,
            )->hash;

            unless ($role && $role->{role} eq 'admin') {
                $c->render(status => 403, json => { error => 'admin_required' });
                return;
            }

            return 1;
        });
    });
}

1;
