package Resonance::Controller::Radio::Stream;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::IOLoop;
use Mojo::UserAgent;
use Scalar::Util qw(weaken);

my $UA_STRING = 'Mozilla/5.0 (compatible; Resonance/0.01; +https://github.com/thomas666-beast/resonance)';

sub stream ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, text => 'invalid id')
        unless defined $id && $id =~ /^\d+$/;

    my $station = $c->pg->db->query(
        'SELECT id, name, stream_url, is_public FROM radio_stations WHERE id = ?',
        $id,
    )->hash;

    return $c->render(status => 404, text => 'station not found')
        unless $station;

    unless ($station->{is_public} || _is_admin($c)) {
        return $c->render(status => 404, text => 'station not found');
    }

    my $url = $station->{stream_url};
    my $log = $c->app->log;

    $log->info("Radio: proxying '$station->{name}' ($url)");

    $c->render_later;

    # Keep the UA alive for the lifetime of the request
    $c->stash(radio_ua => Mojo::UserAgent->new(
        inactivity_timeout => 30,
        connect_timeout    => 10,
        max_redirects      => 5,
    ));
    my $ua = $c->stash('radio_ua');

    my $started      = 0;
    my $current;
    my $client_gone  = 0;

    # True only while the client connection can still accept writes.
    # Calling write_chunk / finish on a dead connection is what
    # crashes the reactor with "Can't call method 'write' on an
    # undefined value" inside Mojo::Server::Daemon.
    my $can_write = sub {
        return 0 if $client_gone;
        return 0 unless $c->tx;
        return 0 unless $c->tx->connection;
        return 1;
    };

    my $abort_upstream = sub {
        if ($current && (my $conn = $current->connection)) {
            Mojo::IOLoop->remove($conn);
        }
    };

    $ua->on(start => sub ($ua, $tx) {
        $current = $tx;

        my $headers = $tx->req->headers;
        $headers->user_agent($UA_STRING);
        $headers->header('Icy-MetaData' => '0');
        $headers->header('Accept'       => '*/*');

        weaken(my $wtx = $tx);

        my $content = $tx->res->content;
        $content->unsubscribe('read');

        my $streaming = 0;

        $content->on(body => sub ($content) {
            return unless $wtx;
            return unless $can_write->();

            my $res  = $wtx->res;
            my $code = $res->code // 0;

            return if $code >= 300 && $code < 400;

            if ($code < 200 || $code >= 300) {
                $log->warn("Radio: upstream HTTP $code " . ($res->message // ''));
                unless ($started++) {
                    eval { $c->render(status => 502, text => 'upstream error') };
                }
                $abort_upstream->();
                return;
            }

            my $ct = $res->headers->content_type // 'audio/mpeg';
            $ct =~ s/;.*//;
            $log->info("Radio: upstream $code, content-type=$ct");

            my $h = $c->res->headers;
            $h->content_type($ct =~ m{^(audio|application/ogg|video/)}i ? $ct : 'audio/mpeg');
            $h->header('Cache-Control'               => 'no-cache, no-store');
            $h->header('Access-Control-Allow-Origin' => '*');

            $c->res->code(200);
            eval { $c->write_chunk };
            $started   = 1;
            $streaming = 1;
        });

        $content->on(read => sub ($content, $bytes) {
            return unless $streaming;
            unless ($can_write->()) {
                $client_gone = 1;
                $abort_upstream->();
                return;
            }
            my $ok = eval { $c->write_chunk($bytes); 1 };
            unless ($ok) {
                $client_gone = 1;
                $abort_upstream->();
            }
        });
    });

    $ua->start($ua->build_tx(GET => $url) => sub ($ua, $tx) {
        if (my $err = $tx->error) {
            $log->warn("Radio: upstream ended: " . ($err->{message} // 'unknown error'));
        }

        $current = undef;

        return if $client_gone;
        return unless $can_write->();

        if ($started) {
            eval { $c->finish };
        }
        else {
            $started = 1;
            eval { $c->render(status => 502, text => 'upstream unavailable') };
        }
    });

    $c->on(finish => sub {
        $log->debug("Radio: client disconnected");
        $client_gone = 1;
        $abort_upstream->();
    });
}

sub _is_admin ($c) {
    my $row = $c->pg->db->query(
        'SELECT role FROM users WHERE id = ?',
        $c->stash('current_user_id'),
    )->hash;
    return $row && $row->{role} eq 'admin';
}

1;
