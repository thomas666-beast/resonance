package Resonance::Controller::Subsonic;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Resonance::Subsonic::Auth qw(verify_subsonic_auth);
use Resonance::Subsonic::Format qw(
    subsonic_response subsonic_error
    format_music_folder
);

# ── dispatcher ───────────────────────────────────────────

sub dispatch ($c) {
    my $method = $c->param('method') // '';
    my $params = { map { $_ => $c->param($_) } qw(u p t s v c f) };

    # Auth: Subsonic uses ?u=...&p=... or ?u=...&t=...&s=...
    my $username = $c->param('u');
    my $user;
    if (defined $username && length $username) {
        $user = $c->pg->db->query(
            q{SELECT id, username, is_active, role, subsonic_password_enc
                FROM users WHERE lower(username) = lower(?)},
            $username,
        )->hash;
    }

    unless (verify_subsonic_auth($c->config->{jwt}{secret}, $user, $params)) {
        return $c->render(json => subsonic_error(40, 'Wrong username or password'));
    }

    # Stash the authenticated user
    $c->stash(subsonic_user => $user);

    my %handlers = (
        ping            => \&_ping,
        getLicense      => \&_get_license,
        getMusicFolders => \&_get_music_folders,
    );

    my $handler = $handlers{$method};
    unless ($handler) {
        return $c->render(json =>
            subsonic_error(0, "Method '$method' not implemented"));
    }

    return $handler->($c);
}

# ── endpoint implementations ─────────────────────────────

sub _ping ($c) {
    $c->render(json => subsonic_response({}));
}

sub _get_license ($c) {
    $c->render(json => subsonic_response({
        license => {
            valid => \1,
        },
    }));
}

sub _get_music_folders ($c) {
    $c->render(json => subsonic_response({
        musicFolders => {
            musicFolder => [
                format_music_folder(1, 'Media'),
            ],
        },
    }));
}

1;
