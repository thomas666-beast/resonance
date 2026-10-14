package Resonance::Controller::Scan;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub active ($c) {
    my $db = $c->pg->db;
    my $rows = $db->query(
        q{SELECT id, task, state, created, started, finished, result, notes
            FROM minion_jobs
           WHERE task = 'scan'
             AND state IN ('inactive', 'active')
           ORDER BY created DESC
           LIMIT 20}
    )->hashes->to_array;

    $c->render(json => { jobs => $rows });
}

sub show ($c) {
    my $id = $c->param('id');

    return $c->render(status => 400, json => { error => 'invalid_job_id' })
        unless $id =~ /^\d+$/;

    my $job = $c->pg->db->query(
        q{SELECT id, task, state, created, started, finished, result, notes, retries
            FROM minion_jobs
           WHERE id = ?},
        $id,
    )->hash;

    return $c->render(status => 404, json => { error => 'job_not_found' })
        unless $job;

    $c->render(json => { job => $job });
}

sub trigger ($c) {
    my $body = $c->req->json // {};
    my $path = $body->{path} // $c->config->{media_root};

    return $c->render(status => 400, json => { error => 'invalid_path' })
        unless defined $path && -d $path;

    my $sp = $c->pg->db->query(
        q{INSERT INTO scan_paths (path) VALUES (?)
          ON CONFLICT (path) DO UPDATE SET path = EXCLUDED.path
          RETURNING id},
        $path,
    )->hash;

    my $job_id = $c->minion->enqueue(scan => [$sp->{id}]);

    $c->render(json => {
        job_id       => $job_id,
        scan_path_id => 0 + $sp->{id},
        path         => $path,
    });
}

sub ws ($c) {
    my $log = $c->app->log;

    $c->websocket(sub ($c) {
        $log->debug("WS client connected");

        # Per-client Redis PubSub subscription.
        # Must stay alive for the lifetime of the socket.
        my $unlisten;
        my $pubsub = $c->redis->pubsub;

        $unlisten = $pubsub->listen('resonance:scan' => sub ($pubsub, $message, $channel) {
            $c->send({json => {channel => $channel, data => $message}});
        });

        # Client disconnect → clean up the Redis subscription
        $c->on(finish => sub ($c, $code, $reason) {
            $log->debug("WS client disconnected ($code)");
            $pubsub->unlisten($unlisten) if $unlisten;
        });

        # We don't expect messages from the client — ignore anything received
        $c->on(message => sub ($c, $msg) {
            $log->debug("WS message ignored: $msg");
        });
    });
}

1;

1;
