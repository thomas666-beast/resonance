package Resonance::Plugin::Auth;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Resonance::Auth qw(verify_access_token);

sub register ($self, $app, $conf) {
    $app->routes->add_shortcut(auth_required => sub ($r) {
        return $r->under(sub ($c) {
            my $header = $c->req->headers->authorization // '';
            my ($scheme, $token) = split /\s+/, $header, 2;

            # Fallback: ?token=… on stream and websocket routes only
            my $path = $c->req->url->path // '';
            if ((!defined $scheme || lc($scheme) ne 'bearer')
                && (   $path =~ m{^/api/stream/}
                    || $path =~ m{^/api/cover/}
                    || $path =~ m{^/api/radio/\d+/stream}
                    || $path =~ m{^/api/ws}
                )) {
                $token = $c->param('token');
                $scheme = 'bearer' if defined $token;
            }

            unless (defined $scheme && lc($scheme) eq 'bearer' && defined $token) {
                $c->render(
                    status => 401,
                    json   => { error => 'missing_token',
                                message => 'Authorization: Bearer <token> required' },
                );
                return;
            }

            my $payload = verify_access_token($c->config->{jwt}{secret}, $token);
            unless ($payload) {
                $c->render(
                    status => 401,
                    json   => { error => 'invalid_token',
                                message => 'Token invalid or expired' },
                );
                return;
            }

            $c->stash(current_user_id => $payload->{sub});
            $c->stash(jwt_payload     => $payload);
            return 1;
        });
    });
}

1;
