package Resonance::Plugin::Auth;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Resonance::Auth qw(verify_access_token);

sub register ($self, $app, $conf) {
    $app->routes->add_shortcut(auth_required => sub ($r) {
        return $r->under(sub ($c) {
            my $header = $c->req->headers->authorization // '';
            my ($scheme, $token) = split /\s+/, $header, 2;

            unless (defined $scheme && lc($scheme) eq 'bearer' && defined $token) {
                $c->render(
                    status => 401,
                    json   => { error => 'missing_token',
                                message => 'Authorization: Bearer <token> required' },
                );
                return;   # false → halt the chain
            }

            my $payload = verify_access_token($c->config->{jwt}{secret}, $token);
            unless ($payload) {
                $c->render(
                    status => 401,
                    json   => { error => 'invalid_token',
                                message => 'Token invalid or expired' },
                );
                return;   # false → halt the chain
            }

            $c->stash(current_user_id => $payload->{sub});
            $c->stash(jwt_payload     => $payload);
            return 1;     # true → continue to the actual route
        });
    });
}

1;
