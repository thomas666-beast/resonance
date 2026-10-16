package Resonance::Util::PodcastFetch;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    cached_episode_path
    download_episode_p
    serve_episode
);

use Mojo::File qw(path);
use Mojo::UserAgent;
use Digest::SHA qw(sha256_hex);
use Resonance::Util::Range qw(serve_file_with_range);

my $UA_STRING         = 'Mozilla/5.0 (compatible; Resonance/0.01)';
my $MAX_DOWNLOAD_SIZE = 500 * 1024 * 1024;    # 500 MB

# ── cache path ───────────────────────────────────────────

sub _cache_dir ($app) {
    my $dir = $app->config->{podcast_cache_dir} // 'data/podcasts';
    path($dir)->make_path unless -d $dir;
    return $dir;
}

sub _episode_file ($app, $ep) {
    my $dir  = _cache_dir($app);
    my $hash = substr(sha256_hex($ep->{audio_url}), 0, 16);
    return "$dir/$ep->{id}-$hash.mp3";
}

sub cached_episode_path ($app, $ep) {
    my $file = _episode_file($app, $ep);
    return (-f $file && -s $file) ? $file : undef;
}

# ── download ─────────────────────────────────────────────

sub download_episode_p ($app, $ep) {
    my $log   = $app->log;
    my $final = _episode_file($app, $ep);
    my $tmp   = "$final.part.$$";

    $log->info("Podcast: downloading episode $ep->{id} from $ep->{audio_url}");

    my $ua = Mojo::UserAgent->new(
        connect_timeout    => 10,
        inactivity_timeout => 60,
        max_redirects      => 5,
        max_response_size  => $MAX_DOWNLOAD_SIZE,
    );
    $ua->transactor->name($UA_STRING);

    return $ua->get_p($ep->{audio_url})->then(sub ($tx) {
        my $res = $tx->result;
        die 'HTTP ' . $res->code . "\n" unless $res->is_success;

        # Mojo streams big bodies to a temp asset rather than holding
        # the whole thing in memory.
        my $asset = $res->content->asset;
        die "empty body\n" unless $asset->size;

        $asset->move_to($tmp);
        rename $tmp, $final or die "rename failed: $!\n";

        $log->info("Podcast: cached $final (" . (-s $final) . " bytes)");
        return $final;
    })->catch(sub ($err) {
        unlink $tmp if -f $tmp;
        chomp(my $msg = "$err");
        die "$msg\n";
    })->finally(sub {
        undef $ua;
    });
}

# ── serve ────────────────────────────────────────────────
# Cache hit → serve with Range.
# Cache miss → download (non-blocking), then serve.
# On any failure, 502.

sub serve_episode ($c, $ep) {
    my $app = $c->app;

    if (my $cached = cached_episode_path($app, $ep)) {
        return serve_file_with_range($c, $cached, mime => 'audio/mpeg');
    }

    $c->render_later;
    download_episode_p($app, $ep)->then(
        sub ($file) {
            serve_file_with_range($c, $file, mime => 'audio/mpeg');
        },
        sub ($err) {
            chomp $err;
            $app->log->warn("Podcast: download failed for episode $ep->{id}: $err");
            $c->render(status => 502, text => 'upstream unavailable');
        },
    )->catch(sub ($err) {
        $app->log->error("Podcast: serving episode $ep->{id} failed: $err");
    });
}

1;
