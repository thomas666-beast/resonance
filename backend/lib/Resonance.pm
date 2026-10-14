package Resonance;
use Mojo::Base 'Mojolicious', -signatures;

use FindBin;
use Dotenv;
use Mojo::Pg;
use Mojo::Redis;

our $VERSION = '0.01';

sub startup ($self) {
  # Load .env from repo root (backend/../.env)
  my $env_file = "$FindBin::Bin/../../.env";
  Dotenv->load($env_file) if -e $env_file;

  # Load config
  $self->plugin('Config' => {
    default => {
      name  => 'Resonance',
      log_level => $ENV{RESONANCE_LOG_LEVEL} // 'debug',
      pg => {
        dsn  => $ENV{POSTGRES_DSN}
              // "postgresql://$ENV{POSTGRES_USER}:$ENV{POSTGRES_PASSWORD}"
               . "\@$ENV{POSTGRES_HOST}:$ENV{POSTGRES_PORT}/$ENV{POSTGRES_DB}",
      },
      redis => {
        url => $ENV{REDIS_URL} // 'redis://127.0.0.1:6379/0',
      },
    },
  });

  $self->config->{allow_registration} = ($ENV{ALLOW_REGISTRATION} // '0') eq '1' ? 1 : 0;

  # Logging
  $self->log->level($self->config->{log_level});

  # Database handle (lazy — connects on first use)
  $self->helper(pg => sub ($c) {
    state $pg = Mojo::Pg->new($c->config->{pg}{dsn});
    return $pg;
  });

  # Redis handle
  $self->helper(redis => sub ($c) {
    state $r = Mojo::Redis->new($c->config->{redis}{url});
    return $r;
  });

  # Routes
  my $r = $self->routes;

  # JWT config
  $self->config->{jwt} = {
    secret     => $ENV{JWT_SECRET} // die("JWT_SECRET is required\n"),
    access_ttl => $ENV{JWT_ACCESS_TTL} // 900,
    refresh_ttl => $ENV{JWT_REFRESH_TTL} // 2592000,
  };

  # Auth plugin
  $self->plugin('Resonance::Plugin::Auth');

  # /api namespace
  my $api = $r->under('/api')->to('Base#api_headers');

  $api->get('/health')->to('Health#check');

  # Public auth routes
  $api->post('/auth/register')->to('Auth#register');
  $api->post('/auth/login')   ->to('Auth#login');
  $api->post('/auth/refresh') ->to('Auth#refresh');

  # Protected
  my $authed = $api->auth_required;
  $authed->post('/auth/logout')->to('Auth#logout');
  $authed->get ('/auth/me')    ->to('Me#show');
  $authed->get ('/auth/tokens')->to('Me#list_tokens');
  $authed->post('/auth/tokens')->to('Me#create_token');
  $authed->delete('/auth/tokens/:id')->to('Me#delete_token');
}

1;
