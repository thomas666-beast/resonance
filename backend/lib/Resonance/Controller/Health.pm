package Resonance::Controller::Health;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub check ($c) {
    my %status = (
        status  => 'ok',
        version => $Resonance::VERSION,
        time    => time(),
        app     => {
            name           => $c->config->{app_name},
            copyright_year => $c->config->{copyright_year},
            admin_contact  => $c->config->{admin_contact},
        },
        services => {},
    );

    # ── Postgres ──
    my $pg_ok = 0;
    my $pg_err;
    eval {
        my $row = $c->pg->db->query('SELECT 1 AS ok')->hash;
        $pg_ok = ($row->{ok} // 0) == 1 ? 1 : 0;
        1;
    } or $pg_err = $@;

    $status{services}{postgres} = {
        ok  => $pg_ok ? \1 : \0,
        ($pg_err ? (error => "$pg_err") : ()),
    };

    # ── Redis ──
    my $redis_ok = 0;
    my $redis_err;
    eval {
        my $pong = $c->redis->db->ping;
        $redis_ok = ($pong && $pong eq 'PONG') ? 1 : 0;
        1;
    } or $redis_err = $@;

    $status{services}{redis} = {
        ok  => $redis_ok ? \1 : \0,
        ($redis_err ? (error => "$redis_err") : ()),
    };

    my $all_ok = $pg_ok && $redis_ok;
    $status{status} = $all_ok ? 'ok' : 'degraded';

    $c->res->code($all_ok ? 200 : 503);
    $c->render(json => \%status);
}

1;
