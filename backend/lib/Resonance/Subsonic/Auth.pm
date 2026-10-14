package Resonance::Subsonic::Auth;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    encrypt_subsonic_password decrypt_subsonic_password
    verify_subsonic_auth
);

use Crypt::AuthEnc::GCM qw(gcm_encrypt_authenticate gcm_decrypt_verify);
use Crypt::PRNG qw(random_bytes random_string);
use Digest::MD5 qw(md5_hex);
use MIME::Base64 qw(encode_base64 decode_base64);

# Derive a 32-byte key from our JWT secret. Using SHA-256 gives us
# uniform 32 bytes regardless of the secret's length.
sub _derive_key ($secret) {
    require Digest::SHA;
    return Digest::SHA::sha256($secret);
}

# ── encryption (AES-256-GCM) ────────────────────────────

sub encrypt_subsonic_password ($secret, $plaintext) {
    my $key   = _derive_key($secret);
    my $nonce = random_bytes(12);

    my ($ciphertext, $tag) = gcm_encrypt_authenticate('AES', $key, $nonce, '', $plaintext);

    # Format: base64(nonce . tag . ciphertext)
    my $blob = $nonce . $tag . $ciphertext;
    return encode_base64($blob, '');
}

sub decrypt_subsonic_password ($secret, $encoded) {
    my $key  = _derive_key($secret);
    my $blob = eval { decode_base64($encoded) };
    return undef unless $blob && length($blob) >= 28;  # 12 nonce + 16 tag

    my $nonce      = substr($blob, 0, 12);
    my $tag        = substr($blob, 12, 16);
    my $ciphertext = substr($blob, 28);

    my $pt = eval {
        gcm_decrypt_verify('AES', $key, $nonce, '', $ciphertext, $tag);
    };
    return $pt;
}

# ── verification ─────────────────────────────────────────

# Given a DB user row and the request params, verify the Subsonic credentials.
# Returns 1 on success, 0 on failure.
sub verify_subsonic_auth ($jwt_secret, $user_row, $params) {
    return 0 unless $user_row;
    return 0 unless $user_row->{is_active};
    return 0 unless defined $user_row->{subsonic_password_enc}
               && length $user_row->{subsonic_password_enc};

    my $plain = decrypt_subsonic_password($jwt_secret, $user_row->{subsonic_password_enc});
    return 0 unless defined $plain;

    # Modern token auth: t = md5(password . salt)
    if (defined $params->{t} && defined $params->{s}) {
        my $expected = md5_hex($plain . $params->{s});
        return $expected eq lc $params->{t} ? 1 : 0;
    }

    # Legacy: p = password, or p = "enc:" . hex(password)
    if (defined $params->{p}) {
        my $given = $params->{p};
        if ($given =~ /^enc:(.+)$/) {
            my $hex = $1;
            return 0 unless $hex =~ /^[0-9a-fA-F]+$/ && length($hex) % 2 == 0;
            $given = pack('H*', $hex);
        }
        # Constant-time comparison
        return length($given) == length($plain)
            && _ct_eq($given, $plain) ? 1 : 0;
    }

    return 0;
}

sub _ct_eq ($a, $b) {
    return 0 unless length($a) == length($b);
    my $diff = 0;
    for my $i (0 .. length($a) - 1) {
        $diff |= ord(substr($a,$i,1)) ^ ord(substr($b,$i,1));
    }
    return $diff == 0;
}

1;
