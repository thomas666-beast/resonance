package Resonance;
use Mojo::Base 'Mojolicious', -signatures;

use Dotenv;
use Cwd            qw(abs_path);
use File::Basename qw(dirname);

use Mojo::Pg;
use Mojo::Redis;

use Resonance::Auth ();

our $VERSION = '0.01';

sub startup ($self) {
    $self->_load_env;
    $self->_configure;
    $self->_setup_logging;
    $self->_register_helpers;
    $self->_register_plugins;
    $self->_register_routes;
}

sub _find_env_file {
    my $dir = abs_path(dirname(__FILE__));
    for (1 .. 6) {
        my $env = "$dir/.env";
        return $env if -e $env;
        my $parent = dirname($dir);
        last if $parent eq $dir;
        $dir = $parent;
    }
    return undef;
}

sub _load_env ($self) {
    my $env_file = $ENV{RESONANCE_ENV_FILE} // _find_env_file();
    Dotenv->load($env_file) if $env_file && -e $env_file;
}

sub _configure ($self) {
    $self->plugin('Config' => {
        default => {
            name      => 'Resonance',
            log_level => $ENV{RESONANCE_LOG_LEVEL} // 'debug',
            pg => {
                dsn => $ENV{POSTGRES_DSN}
                    // "postgresql://$ENV{POSTGRES_USER}:$ENV{POSTGRES_PASSWORD}"
                     . "\@$ENV{POSTGRES_HOST}:$ENV{POSTGRES_PORT}/$ENV{POSTGRES_DB}",
            },
            redis => {
                url => $ENV{REDIS_URL} // 'redis://127.0.0.1:6379/0',
            },
            jwt => {
                secret      => $ENV{JWT_SECRET}      // die "JWT_SECRET required\n",
                access_ttl  => ($ENV{JWT_ACCESS_TTL}  // 900)       + 0,
                refresh_ttl => ($ENV{JWT_REFRESH_TTL} // 2_592_000) + 0,
            },
        },
    });

    $self->config->{env}                 = $ENV{RESONANCE_ENV} // 'development';
    $self->config->{allow_registration}  = ($ENV{ALLOW_REGISTRATION} // '0') eq '1' ? 1 : 0;
    $self->config->{media_root}          = $ENV{MEDIA_ROOT};
    $self->config->{cover_cache_dir}     = $ENV{COVER_CACHE_DIR}     // 'data/covers';
    $self->config->{transcode_cache_dir} = $ENV{TRANSCODE_CACHE_DIR} // 'data/transcodes';

    $self->config->{app_name}       = $ENV{APP_NAME}           // 'Resonance';
    $self->config->{copyright_year} = (localtime)[5] + 1900;
    $self->config->{admin_contact}  = $ENV{ADMIN_CONTACT}      // '';
}

sub _setup_logging ($self) {
    $self->log->level($self->config->{log_level});
}

sub _register_helpers ($self) {
    $self->helper(pg => sub ($c) {
        state $pg = Mojo::Pg->new($c->config->{pg}{dsn});
        return $pg;
    });

    $self->helper(redis => sub ($c) {
        state $r = Mojo::Redis->new($c->config->{redis}{url});
        return $r;
    });
}

sub _register_plugins ($self) {
    $self->plugin('Resonance::Plugin::Admin');
    $self->plugin('Resonance::Plugin::Auth');

    $self->plugin('Minion' => { Pg => $self->config->{pg}{dsn} });
    $self->minion->backend->pg->migrations->name('minion')->migrate;

    require Resonance::Job::Scan;
    Resonance::Job::Scan::register($self->minion);

    $self->plugin('SecurityHeader');
}

sub _register_routes ($self) {
    my $r = $self->routes;

    $self->_routes_subsonic($r);

    # WebSocket route — must be registered as websocket, not under an auth chain
    use Resonance::Auth qw(verify_access_token);

    # ... inside _register_routes ...
    $r->websocket('/api/ws')->to(cb => sub ($c) {
        my $log = $c->app->log;

        my $token = $c->param('token');
        unless (defined $token && length $token) {
            return $c->render(status => 401, text => 'missing token');
        }

        my $payload = verify_access_token($c->config->{jwt}{secret}, $token);
        unless ($payload) {
            return $c->render(status => 401, text => 'invalid token');
        }

        $log->debug("WS client connected (user $payload->{sub})");

        my $channel = 'resonance:scan';
        my $pubsub  = $c->redis->pubsub;

        my $cb = $pubsub->listen($channel => sub ($pubsub, $message, $channel) {
            return unless $c->tx;   # connection already gone
            $c->send({json => {channel => $channel, data => $message}});
        });

        $c->on(finish => sub ($c, $code, $reason) {
            $log->debug("WS client disconnected (" . ($code // '-') . ")");
            $pubsub->unlisten($channel => $cb);
        });

        $c->on(message => sub ($c, $msg) {
            $log->debug("WS message ignored: $msg");
        });
    });

    my $api = $r->under('/api')->to('Base#api_headers');
    $self->_routes_public($api);

    my $authed = $api->auth_required;
    $self->_routes_account($authed);
    $self->_routes_scan($authed);
    $self->_routes_library($authed);
    $self->_routes_favorites($authed);
    $self->_routes_playlists($authed);
    $self->_routes_home($authed);
    $self->_routes_admin($authed);
    $self->_routes_radio($authed);
}

sub _routes_subsonic ($self, $r) {
    $r->any('/rest/:method')->to('Subsonic#dispatch');
}

sub _routes_public ($self, $api) {
    $api->get ('/health')        ->to('Health#check');
    $api->post('/auth/register') ->to('Auth#register');
    $api->post('/auth/login')    ->to('Auth#login');
    $api->post('/auth/refresh')  ->to('Auth#refresh');
}

sub _routes_account ($self, $authed) {
    $authed->post  ('/auth/logout')      ->to('Auth#logout');
    $authed->get   ('/auth/me')          ->to('Me#show');
    $authed->get   ('/auth/tokens')      ->to('Me#list_tokens');
    $authed->post  ('/auth/tokens')      ->to('Me#create_token');
    $authed->delete('/auth/tokens/:id')  ->to('Me#delete_token');

    $authed->post('/me/subsonic-password') ->to('Me#set_subsonic_password');
    $authed->get ('/me/subsonic')          ->to('Me#subsonic_status');
    $authed->post('/auth/change-password') ->to('Auth#change_password');
}

sub _routes_scan ($self, $authed) {
    $authed->get ('/scan/active')   ->to('Scan#active');
    $authed->get ('/scan/jobs/:id') ->to('Scan#show');
    $authed->post('/scan')          ->to('Scan#trigger');
}

sub _routes_library ($self, $authed) {
    $authed->get('/artists')           ->to('Library#artists');
    $authed->get('/artists/:id')       ->to('Library#artist_detail');
    $authed->get('/albums')            ->to('Library#albums');
    $authed->get('/albums/:id')        ->to('Library#album_detail');
    $authed->get('/tracks/:id')        ->to('Library#track_detail');
    $authed->get('/stream/:track_id')  ->to('Stream#stream');
    $authed->get('/cover/:album_id')   ->to('Cover#show');
    $authed->get('/search')            ->to('Search#search');
}

sub _routes_favorites ($self, $authed) {
    $authed->get   ('/favorites')            ->to('Favorites#list');
    $authed->get   ('/favorites/ids')        ->to('Favorites#ids');
    $authed->post  ('/favorites/:track_id')  ->to('Favorites#add');
    $authed->delete('/favorites/:track_id')  ->to('Favorites#remove');
}

sub _routes_playlists ($self, $authed) {
    $authed->get   ('/playlists')                       ->to('Playlists#list');
    $authed->post  ('/playlists')                       ->to('Playlists#create');
    $authed->get   ('/playlists/:id')                   ->to('Playlists#show');
    $authed->patch ('/playlists/:id')                   ->to('Playlists#update');
    $authed->delete('/playlists/:id')                   ->to('Playlists#remove');
    $authed->post  ('/playlists/:id/tracks')            ->to('Playlists#add_track');
    $authed->delete('/playlists/:id/tracks/:track_id')  ->to('Playlists#remove_track');
    $authed->patch ('/playlists/:id/reorder')           ->to('Playlists#reorder');
}

sub _routes_home ($self, $authed) {
    $authed->get ('/home')             ->to('Home#index');
    $authed->post('/plays/:track_id')  ->to('Plays#log_play');
}

sub _routes_admin ($self, $authed) {
    my $admin = $authed->admin_required;
    $admin->get   ('/admin/users')      ->to('Admin#list_users');
    $admin->post  ('/admin/users')      ->to('Admin#create_user');
    $admin->patch ('/admin/users/:id')  ->to('Admin#update_user');
    $admin->delete('/admin/users/:id')  ->to('Admin#delete_user');
    $admin->get   ('/admin/stats')      ->to('Admin#stats');
    $admin->get   ('/admin/transcode')  ->to('Admin#transcode_stats');
    $admin->delete('/admin/transcode')  ->to('Admin#transcode_clear');
    $admin->get   ('/admin/missing')            ->to('Admin#missing_tracks');
    $admin->post  ('/admin/missing/purge')      ->to('Admin#purge_missing');
    $admin->post  ('/admin/missing/:id/restore')->to('Admin#restore_track');
}

sub _routes_radio ($self, $authed) {
    $authed->get   ('/radio')               ->to('Radio#list');
    $authed->get   ('/radio/:id')           ->to('Radio#show');
    $authed->get   ('/radio/:id/stream')    ->to('Radio::Stream#stream');
    $authed->get('/radio/:id/now-playing')->to('Radio::Stream#now_playing');
    $authed->post  ('/radio')               ->to('Radio#create');
    $authed->patch ('/radio/:id')           ->to('Radio#update');
    $authed->delete('/radio/:id')           ->to('Radio#remove');
}

1;
