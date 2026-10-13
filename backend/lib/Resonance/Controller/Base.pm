package Resonance::Controller::Base;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# Runs before every /api route — sets JSON headers and default error shape.
sub api_headers ($c) {
  $c->res->headers->content_type('application/json; charset=utf-8');
  $c->res->headers->header('X-Content-Type-Options' => 'nosniff');
  $c->res->headers->header('X-Frame-Options'        => 'DENY');
  $c->res->headers->header('Referrer-Policy'        => 'no-referrer');

  # JSON body parser for POST/PUT/PATCH
  $c->req->json if $c->req->method =~ /^(POST|PUT|PATCH)$/;

  return 1;
}

1;
