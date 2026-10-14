package Resonance;
use Mojo::Base 'Mojolicious', -signatures;

use Dotenv;
use Cwd        qw(abs_path);
use File::Basename qw(dirname);

use Mojo::Pg;
use Mojo::Redis;

our $VERSION = '0.01';

# Walk up from this file's directory looking for a .env file.
# Works no matter how the app is invoked (bin/resonance, -e one-liner, worker).
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

sub startup ($self) {
    my $env_file = $ENV{RESONANCE_ENV_FILE} // _find_env_file();
    Dotenv->load($env_file) if $env_file && -e $env_file;

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
                access_ttl  => $ENV{JWT_ACCESS_TTL}  // 900,
                refresh_ttl => $ENV{JWT_REFRESH_TTL} // 2592000,
            },
        },
    });

    $self->config->{env} = $ENV{RESONANCE_ENV} // 'development';

    $self->config->{allow_registration} =
        ($ENV{ALLOW_REGISTRATION} // '0') eq '1' ? 1 : 0;
    $self->config->{media_root} = $ENV{MEDIA_ROOT};
    $self->config->{cover_cache_dir} = $ENV{COVER_CACHE_DIR} // 'data/covers';

    $self->log->level($self->config->{log_level});

    $self->helper(pg => sub ($c) {
        state $pg = Mojo::Pg->new($c->config->{pg}{dsn});
        return $pg;
    });

    $self->helper(redis => sub ($c) {
        state $r = Mojo::Redis->new($c->config->{redis}{url});
        return $r;
    });

    # Plugins
    $self->plugin('Resonance::Plugin::Admin');
    $self->plugin('Resonance::Plugin::Auth');
    $self->plugin('Minion' => { Pg => $self->config->{pg}{dsn} });
    $self->minion->backend->pg->migrations->name('minion')->migrate;

    require Resonance::Job::Scan;
    Resonance::Job::Scan::register($self->minion);

    $self->plugin('SecurityHeader');

    # Routes
    my $r   = $self->routes;

    # Subsonic protocol — mounted at /rest/* for client compatibility
    $r->any('/rest/:method')->to('Subsonic#dispatch');

    my $api = $r->under('/api')->to('Base#api_headers');

    $api->get ('/health')          ->to('Health#check');
    $api->post('/auth/register')   ->to('Auth#register');
    $api->post('/auth/login')      ->to('Auth#login');
    $api->post('/auth/refresh')    ->to('Auth#refresh');

    my $authed = $api->auth_required;
    $authed->post  ('/auth/logout')     ->to('Auth#logout');
    $authed->get   ('/auth/me')         ->to('Me#show');
    $authed->get   ('/auth/tokens')     ->to('Me#list_tokens');
    $authed->post  ('/auth/tokens')     ->to('Me#create_token');
    $authed->delete('/auth/tokens/:id') ->to('Me#delete_token');


    $authed->get   ('/scan/active')     ->to('Scan#active');
    $authed->get   ('/scan/jobs/:id')   ->to('Scan#show');
    $authed->post  ('/scan')            ->to('Scan#trigger');

    $authed->get('/artists')          ->to('Library#artists');
    $authed->get('/artists/:id')      ->to('Library#artist_detail');
    $authed->get('/albums')           ->to('Library#albums');
    $authed->get('/albums/:id')       ->to('Library#album_detail');
    $authed->get('/tracks/:id')       ->to('Library#track_detail');
    $authed->get('/stream/:track_id') ->to('Stream#stream');

    $authed->get('/ws')->to('Scan#ws');

    $authed->get   ('/favorites')                    ->to('Favorites#list');
    $authed->get   ('/favorites/ids')                ->to('Favorites#ids');
    $authed->post  ('/favorites/:track_id')          ->to('Favorites#add');
    $authed->delete('/favorites/:track_id')          ->to('Favorites#remove');

    $authed->get   ('/playlists')                            ->to('Playlists#list');
    $authed->post  ('/playlists')                            ->to('Playlists#create');
    $authed->get   ('/playlists/:id')                        ->to('Playlists#show');
    $authed->patch ('/playlists/:id')                        ->to('Playlists#update');
    $authed->delete('/playlists/:id')                        ->to('Playlists#remove');
    $authed->post  ('/playlists/:id/tracks')                 ->to('Playlists#add_track');
    $authed->delete('/playlists/:id/tracks/:track_id')       ->to('Playlists#remove_track');
    $authed->patch ('/playlists/:id/reorder')                ->to('Playlists#reorder');

    $authed->get('/search')->to('Search#search');

    $authed->get('/cover/:album_id')->to('Cover#show');

    $authed->get ('/home')              ->to('Home#index');
    $authed->post('/plays/:track_id')   ->to('Plays#log_play');

    $authed->get('/admin/users')   ->to('Admin#list_users');
    $authed->post('/admin/users')   ->to('Admin#create_user');
    $authed->patch('/admin/users/:id')   ->to('Admin#update_user');
    $authed->delete('/admin/users/:id')   ->to('Admin#delete_user');
    $authed->get('/admin/stats')   ->to('Admin#stats');

    $authed->post('/me/subsonic-password') ->to('Me#set_subsonic_password');
    $authed->get ('/me/subsonic')          ->to('Me#subsonic_status');
}

1;
