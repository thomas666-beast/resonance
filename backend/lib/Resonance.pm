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

  # /api namespace
  my $api = $r->under('/api')->to('Base#api_headers');

  $api->get('/health')->to('Health#check');
}

1;
