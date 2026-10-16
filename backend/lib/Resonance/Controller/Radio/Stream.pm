package Resonance::Controller::Radio::Stream;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use List::Util qw(min);
use Mojo::IOLoop;
use Mojo::JSON qw(encode_json);
use Mojo::UserAgent;
use Mojo::Util qw(decode encode);
use Scalar::Util qw(weaken);

use Resonance::Auth qw(verify_access_token);

my $UA_STRING = 'Mozilla/5.0 (compatible; Resonance/0.01; +https://github.com/thomas666-beast/resonance)';

sub stream ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, text => 'invalid id')
        unless defined $id && $id =~ /^\d+$/;

    # --- Auth: Bearer header or ?token= ---------------------------------
    my $payload = _authenticate($c)
        or return $c->render(status => 401, text => 'unauthorized');
    $c->stash(current_user_id => $payload->{sub});

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

    # We write the response ourselves, so disable auto-rendering
    $c->render_later;

    my $ua = Mojo::UserAgent->new(
        inactivity_timeout => 30,
        connect_timeout    => 10,
        max_redirects      => 5,
        max_response_size  => 0,      # 0 = unlimited (radio streams never end)
    );

    # Keep the UA alive for the whole request (released in finish handler)
    $c->stash('radio.ua' => $ua);

    my ($started, $current);
    my $total_bytes = 0;

    # Close the upstream connection (stops the download)
    my $abort_upstream = sub {
        if ($current && (my $conn = $current->connection)) {
            Mojo::IOLoop->remove($conn);
        }
    };

    # Store + publish a new "now playing" title
    my $last_title = '';
    my $on_title = sub ($title) {
        return unless defined $title && length $title && $title ne $last_title;
        $last_title = $title;
        $log->info("Radio: now playing on '$station->{name}': $title");

        my $redis = $c->app->redis;
        $redis->db->set_p("radio:$id:now_playing", encode('UTF-8', $title), 'EX', 21600)
            ->catch(sub ($err) { $log->warn("Radio: redis set failed: $err") });

        eval {
            $redis->db->publish('resonance:radio' => encode_json({
                station_id => $id + 0,
                title      => $title,
            }));
        };
        $log->warn("Radio: publish failed: $@") if $@;
    };

    # Fires for the initial request AND for every redirect hop
    $ua->on(start => sub ($ua, $tx) {
        $current = $tx;

        my $headers = $tx->req->headers;
        $headers->user_agent($UA_STRING);
        $headers->header('Icy-MetaData'    => '1');          # ask for "now playing"
        $headers->header('Accept'          => '*/*');
        $headers->header('Accept-Encoding' => 'identity');   # no gzip

        weaken(my $wtx = $tx);

        my $content = $tx->res->content;

        $content->auto_decompress(0);   # never touch the audio bytes
        $content->unsubscribe('read');  # don't buffer the body in memory
        $content->relaxed(1);           # read until the server closes

        my $streaming = 0;

        # ICY parser state (per upstream response)
        my $metaint    = 0;       # audio bytes between metadata blocks (0 = none)
        my $state      = 'audio'; # audio -> len -> meta -> audio ...
        my $audio_left = 0;
        my $meta_left  = 0;
        my $meta_buf   = '';

        # Takes a raw upstream chunk, returns the audio only
        my $strip_icy = sub ($bytes) {
            return $bytes unless $metaint;

            my $audio = '';
            while (length $bytes) {
                if ($state eq 'audio') {
                    my $take = min($audio_left, length $bytes);
                    $audio      .= substr($bytes, 0, $take, '');
                    $audio_left -= $take;
                    $state = 'len' if $audio_left == 0;
                }
                elsif ($state eq 'len') {
                    my $len = ord(substr($bytes, 0, 1, '')) * 16;
                    if ($len) {
                        ($meta_left, $meta_buf, $state) = ($len, '', 'meta');
                    }
                    else {
                        ($audio_left, $state) = ($metaint, 'audio');
                    }
                }
                else {    # meta
                    my $take = min($meta_left, length $bytes);
                    $meta_buf  .= substr($bytes, 0, $take, '');
                    $meta_left -= $take;
                    if ($meta_left == 0) {
                        if ($meta_buf =~ /StreamTitle='(.*?)';/s) {
                            my $raw   = $1;
                            my $title = decode('UTF-8', $raw) // decode('ISO-8859-1', $raw);
                            $on_title->($title);
                        }
                        ($audio_left, $state) = ($metaint, 'audio');
                    }
                }
            }
            return $audio;
        };

        # Emitted once, when the upstream headers have been parsed
        # (and before Mojo starts parsing the body)
        $content->on(body => sub ($content) {
            return unless $wtx;
            my $res  = $wtx->res;
            my $code = $res->code // 0;
            my $rh   = $res->headers;

            # Redirect hop: ignore, the UA will follow it
            return if $code >= 300 && $code < 400;

            # "Transfer-Encoding: identity" means "no encoding", but Mojo treats
            # any Transfer-Encoding header as chunked and would try to parse
            # chunk sizes out of the MP3 data. Drop it.
            if (lc($rh->transfer_encoding // '') eq 'identity') {
                $rh->remove('Transfer-Encoding');
            }

            if ($code < 200 || $code >= 300) {
                $log->warn("Radio: upstream HTTP $code " . ($res->message // ''));
                unless ($started++) {
                    $c->render(status => 502, text => 'upstream error') if $c->tx;
                }
                $abort_upstream->();
                return;
            }

            my $ct = $rh->content_type // 'audio/mpeg';
            $ct =~ s/;.*//;

            my $mi = $rh->header('icy-metaint');
            if (defined $mi && $mi =~ /^\d+$/ && $mi > 0) {
                $metaint    = $mi + 0;
                $audio_left = $metaint;
            }
            $log->info("Radio: upstream $code, content-type=$ct, "
                . ($metaint ? "ICY metadata every $metaint bytes" : 'no ICY metadata'));

            return unless $c->tx;    # client already gone

            my $h = $c->res->headers;
            $h->content_type($ct =~ m{^(audio|application/ogg|video/)}i ? $ct : 'audio/mpeg');
            $h->header('Cache-Control'               => 'no-cache, no-store');
            $h->header('Access-Control-Allow-Origin' => '*');
            $h->header('Connection'                  => 'close');

            $c->res->code(200);
            $c->write;               # send headers; body is raw audio, no chunk framing
            $started   = 1;
            $streaming = 1;
        });

        # Emitted for every chunk of the upstream body
        $content->on(read => sub ($content, $bytes) {
            return unless $streaming;
            return unless length $bytes;     # skip empty events
            return $abort_upstream->() unless $c->tx;

            my $audio = $strip_icy->($bytes);
            return unless length $audio;

            $log->debug('Radio: first audio chunk (' . length($audio) . ' bytes)')
                unless $total_bytes;
            $total_bytes += length $audio;

            $c->write($audio);
        });
    });

    # Fires when the upstream transaction ends (error, EOF, or aborted)
    $ua->start($ua->build_tx(GET => $url) => sub ($ua, $tx) {
        my $err = $tx->error;
        $log->info(
            "Radio: upstream finished after $total_bytes bytes"
          . ($err ? ' (error: ' . ($err->{message} // 'unknown') . ')' : '')
        );

        return unless $c->tx;

        if ($started) {
            $c->finish;              # close the stream
        }
        else {
            $started = 1;
            $c->render(status => 502, text => 'upstream unavailable');
        }
    });

    # Client went away (or stream ended): stop pulling from upstream
    # and release the UA
    $c->on(finish => sub ($c, @) {
        $log->debug("Radio: client disconnected after $total_bytes bytes");
        $abort_upstream->();
        delete $c->stash->{'radio.ua'};
    });
}

# GET /api/radio/:id/now-playing  (behind $authed)
sub now_playing ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, json => {error => 'invalid id'})
        unless defined $id && $id =~ /^\d+$/;

    $c->render_later;
    $c->redis->db->get_p("radio:$id:now_playing")->then(sub ($raw) {
        my $title = defined $raw ? decode('UTF-8', $raw) : undef;
        $c->render(json => {station_id => $id + 0, title => $title});
    })->catch(sub ($err) {
        $c->app->log->warn("Radio: redis get failed: $err");
        $c->render(json => {station_id => $id + 0, title => undef});
    });
}

# Bearer header or ?token= -> JWT payload, or undef
sub _authenticate ($c) {
    my $token = $c->param('token');

    unless (defined $token && length $token) {
        my $auth = $c->req->headers->authorization // '';
        ($token) = $auth =~ /^Bearer\s+(\S+)$/i;
    }

    return undef unless defined $token && length $token;
    return verify_access_token($c->config->{jwt}{secret}, $token);
}

sub _is_admin ($c) {
    my $row = $c->pg->db->query(
        'SELECT role FROM users WHERE id = ?',
        $c->stash('current_user_id'),
    )->hash;
    return $row && $row->{role} eq 'admin';
}

1;
