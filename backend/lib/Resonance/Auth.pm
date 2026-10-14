package Resonance::Auth;
use Mojo::Base -strict, -signatures;

use Crypt::Argon2 qw/argon2id_pass argon2id_verify/;
use Crypt::JWT    qw/encode_jwt decode_jwt/;
use Crypt::PRNG   qw/random_string random_string_from/;
use Digest::SHA   qw/sha256_hex/;
use Exporter 'import';

our @EXPORT_OK = qw(
    hash_password verify_password
    issue_access_token verify_access_token
    generate_refresh_token hash_token
    generate_device_token
);

# ── Passwords ────────────────────────────────────────────

sub hash_password ($password, $memory = '32M', $time = 3, $par = 1) {
    my $salt = random_string(16);
    return argon2id_pass($password, $salt, $time, $memory, $par, 32);
}

sub verify_password ($encoded, $password) {
    return 0 unless defined $encoded && defined $password;
    my $ok = eval { argon2id_verify($encoded, $password) };
    return $ok ? 1 : 0;
}

# ── Access tokens (JWT, HS256) ───────────────────────────

sub issue_access_token ($secret, $user_id, $ttl = 900, $extra = {}) {
    $ttl //= 900;   # caller may pass undef explicitly

    die "JWT secret must be at least 32 bytes\n"
        unless defined $secret && length($secret) >= 32;

    my $now = time();
    my $payload = {
        sub => "$user_id",
        iat => $now,
        exp => $now + $ttl,
        jti => random_string(16),
        %$extra,
    };

    return encode_jwt(
        payload => $payload,
        key     => $secret,
        alg     => 'HS256',
    );
}

sub verify_access_token ($secret, $token) {
    return undef unless defined $secret && defined $token;

    my $payload = eval {
        decode_jwt(
            token        => $token,
            key          => $secret,
            accepted_alg => 'HS256',
        );
    };
    return $payload || undef;
}

# ── Refresh & device tokens (opaque, hashed at rest) ─────

sub generate_refresh_token () {
    return random_string_from(
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_',
        32,
    );
}

sub generate_device_token () {
    return 'rsk_' . random_string(48);
}

sub hash_token ($token) {
    return sha256_hex($token);
}

1;
