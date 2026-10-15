package Resonance::Controller::Radio::Stream;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub stream ($c) {
    my $id = $c->param('id');
    return $c->render(status => 400, text => 'invalid id')
        unless $id =~ /^\d+$/;

    my $station = $c->pg->db->query(
        'SELECT id, name, stream_url, is_public FROM radio_stations WHERE id = ?',
        $id,
    )->hash;

    return $c->render(status => 404, text => 'station not found')
        unless $station;

    # Access control: non-admins see only public stations
    unless ($station->{is_public} || _is_admin($c)) {
        return $c->render(status => 404, text => 'station not found');
    }

    my $url = $station->{stream_url};

    # Set response headers up front. Content-Type may be overwritten
    # once the upstream responds.
    $c->res->code(200);
    $c->res->headers->content_type('audio/mpeg');
    $c->res->headers->header('Cache-Control' => 'no-cache, no-store');
    $c->res->headers->header('Access-Control-Allow-Origin' => '*');

    my $ua = Mojo::UserAgent->new(
        inactivity_timeout => 30,   # abort if no data for 30s
        connect_timeout    => 10,
    );

    # Radio hosts often return ICY/Shoutcast-style responses, or
    # redirect to another URL. Follow 3 redirects.
    $ua->max_redirects(3);

    my $upstream;
    $c->app->log->info("Radio: proxying '$station->{name}' ($url)");

    $upstream = $ua->build_tx(GET => $url);
    $upstream->req->headers->user_agent('Resonance/0.01');
    $upstream->req->headers->header('Icy-MetaData' => '0');

    $ua->start($upstream => sub ($ua, $tx) {
        if ($tx->res->is_error) {
            $c->app->log->warn("Radio upstream error: " . $tx->res->message);
            $c->write('');
            $c->finish(502, 'upstream error');
            return;
        }

        # Forward the upstream content type if it's an audio type
        my $ct = $tx->res->headers->content_type // '';
        $c->res->headers->content_type($ct)
            if $ct =~ m{^(audio|application/ogg|video/)}i;

        $c->write;
    });

    # Send chunks as they arrive from upstream
    $upstream->res->content->on(body => sub ($content, $chunk) {
        $c->write($chunk);
    });

    # Client disconnected → abort upstream immediately so we don't
    # keep pulling bytes into a dead connection
    $c->on(finish => sub ($c, $code, $reason) {
        $c->app->log->debug("Radio: client disconnected ($code)");
        eval { $upstream->req->abort };
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
