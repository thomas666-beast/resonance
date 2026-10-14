use Mojo::Base -strict;
use Test::More;

use lib 'lib';
use Resonance::Auth qw(
    hash_password verify_password
    issue_access_token verify_access_token
    generate_refresh_token hash_token
    generate_device_token
);

# ── Passwords ──
my $pw = "correct horse battery staple";
my $hash = hash_password($pw);
like   $hash, qr/^\$argon2id\$/, 'hash has argon2id prefix';
ok     verify_password($hash, $pw),     'correct password verifies';
ok   ! verify_password($hash, "wrong"), 'wrong password rejected';
ok   ! verify_password(undef,  $pw),    'undef hash rejected';

# ── JWT ──
my $secret = 'a' x 32;
my $token  = issue_access_token($secret, 42, 60);
like   $token, qr/^ey/, 'JWT looks like a JWT';

my $dec = verify_access_token($secret, $token);
ok     $dec, 'token decodes';
is     $dec->{sub}, '42', 'sub is the user id';
ok     $dec->{exp} > time(), 'exp is in the future';

ok   ! verify_access_token('b' x 32, $token), 'wrong key rejected';
ok   ! verify_access_token($secret, 'garbage'), 'garbage rejected';

# ── Refresh / device tokens ──
my $rt = generate_refresh_token();
ok length($rt) >= 32, 'refresh token is long enough';
isnt $rt, generate_refresh_token(), 'refresh tokens are unique';

my $dt = generate_device_token();
like $dt, qr/^rsk_/, 'device token has rsk_ prefix';

is hash_token("abc"), hash_token("abc"), 'hash is deterministic';
isnt hash_token("abc"), hash_token("abd"), 'different inputs → different hashes';

done_testing;
