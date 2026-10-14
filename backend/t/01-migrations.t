use Mojo::Base -strict;
use Test::More;
use Mojo::Pg;

my $dsn = $ENV{TEST_PG_DSN}
       // 'postgresql://resonance:change-me@127.0.0.1:5432/resonance_test';

my $pg = Mojo::Pg->new($dsn);

# Fresh schema (dev/test only)
$pg->db->query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');

my $m = $pg->migrations->from_dir('migrations');
$m->migrate;

my $db = $pg->db;
my $tables = $db->query(
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
)->arrays->map(sub { $_->[0] })->to_array;

my %expected = map { $_ => 1 } qw(
    albums api_tokens artists genres playlist_tracks playlists
    scan_paths tracks tracks_genres users
);

for my $t (sort keys %expected) {
    ok(grep { $_ eq $t } @$tables, "table $t exists");
}

ok(grep { $_ eq 'mojo_migrations' } @$tables, "mojo_migrations exists");

done_testing;
