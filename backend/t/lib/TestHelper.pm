package TestHelper;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    fresh_app fresh_db seed_users seed_library
    login_as make_audio_file cleanup_audio_file
);

use FindBin;
use lib "$FindBin::Bin/../../lib";

sub _set_test_env () {
    $ENV{JWT_SECRET}            //= 'a' x 32;
    $ENV{ALLOW_REGISTRATION}    //= '1';
    $ENV{POSTGRES_HOST}         //= '127.0.0.1';
    $ENV{POSTGRES_PORT}         //= 5432;
    $ENV{POSTGRES_DB}           =  'resonance_test';
    $ENV{POSTGRES_USER}         //= 'resonance';
    $ENV{POSTGRES_PASSWORD}     //= 'change-me';
    $ENV{REDIS_URL}             //= 'redis://127.0.0.1:6379/0';
    $ENV{RESONANCE_LOG_LEVEL}   =  'error';
    $ENV{TRANSCODE_CACHE_DIR}   //= '/tmp/resonance-test-transcodes';
    $ENV{COVER_CACHE_DIR}       //= '/tmp/resonance-test-covers';
}

sub fresh_app () {
    _set_test_env();
    require Resonance;
    my $app = Resonance->new;
    return $app;
}

sub fresh_db ($app) {
    my $db = $app->pg->db;
    $db->query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
    $app->pg->migrations->from_dir('migrations')->migrate;
    $app->minion->backend->pg->migrations->name('minion')->migrate;
    return 1;
}

sub seed_users ($app) {
    require Resonance::Auth;
    require Resonance::Subsonic::Auth;
    my $hash = Resonance::Auth::hash_password('test-pass-12345');
    my $sub_enc = Resonance::Subsonic::Auth::encrypt_subsonic_password(
        $app->config->{jwt}{secret}, 'sub-pass-12345',
    );

    my $db = $app->pg->db;

    my $admin = $db->query(
        q{INSERT INTO users (username, email, password_hash, role, subsonic_password_enc)
          VALUES ('admin', 'admin@test', ?, 'admin', ?) RETURNING id, username},
        $hash, $sub_enc,
    )->hash;

    my $user = $db->query(
        q{INSERT INTO users (username, email, password_hash, role, subsonic_password_enc)
          VALUES ('alice', 'alice@test', ?, 'user', ?) RETURNING id, username},
        $hash, $sub_enc,
    )->hash;

    return { admin => $admin, user => $user };
}

sub seed_library ($app, $users) {
    my $db = $app->pg->db;

    my @artist_names = ('Pink Floyd', 'Radiohead', 'Boards of Canada');
    my @artists;
    for my $name (@artist_names) {
        push @artists, $db->query(
            'INSERT INTO artists (name) VALUES (?) RETURNING id, name',
            $name,
        )->hash;
    }

    my @albums;
    my @album_defs = (
        [$artists[0]{id}, 'The Dark Side of the Moon', 1973],
        [$artists[0]{id}, 'Wish You Were Here',       1975],
        [$artists[1]{id}, 'OK Computer',              1997],
        [$artists[1]{id}, 'Kid A',                    2000],
        [$artists[2]{id}, 'Music Has the Right to Children', 1998],
    );

    for my $def (@album_defs) {
        push @albums, $db->query(
            q{INSERT INTO albums (title, artist_id, year)
              VALUES (?, ?, ?) RETURNING id, title, artist_id},
            $def->[1], $def->[0], $def->[2],
        )->hash;
    }

    my @tracks;
    my $track_num = 0;
    for my $album (@albums) {
        for my $n (1 .. 3) {
            $track_num++;
            push @tracks, $db->query(
                q{INSERT INTO tracks
                      (title, album_id, artist_id, track_number,
                       duration_ms, path, file_size, mime_type, codec)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                  RETURNING id, title, album_id, artist_id},
                "Track $track_num on $album->{title}",
                $album->{id},
                $album->{artist_id},
                $n,
                180000,
                "/tmp/fake-$track_num.mp3",
                1000000,
                'audio/mpeg',
                'mp3',
            )->hash;
        }
    }

    my $playlist = $db->query(
        q{INSERT INTO playlists (user_id, name, is_public)
          VALUES (?, 'Test Playlist', FALSE)
          RETURNING id, name},
        $users->{user}{id},
    )->hash;

    for my $i (0 .. 2) {
        $db->query(
            q{INSERT INTO playlist_tracks (playlist_id, track_id, position)
              VALUES (?, ?, ?)},
            $playlist->{id}, $tracks[$i]{id}, $i + 1,
        );
    }

    return {
        artists  => \@artists,
        albums   => \@albums,
        tracks   => \@tracks,
        playlist => $playlist,
    };
}

sub login_as ($t, $username, $password = 'test-pass-12345') {
    $t->post_ok('/api/auth/login' => json => {
        username => $username,
        password => $password,
    })->status_is(200);
    my $token = $t->tx->res->json->{access_token};
    $t->ua->once(start => sub {
        my ($ua, $tx) = @_;
        $tx->req->headers->authorization("Bearer $token");
    });
    return $token;
}

sub make_audio_file () {
    require Resonance::Util::Transcode;
    return undef unless Resonance::Util::Transcode::ffmpeg_available();

    my $path = "/tmp/resonance-test-" . int(rand(1_000_000)) . ".mp3";

    system(
        'ffmpeg', '-y', '-v', 'error',
        '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=mono',
        '-t', '1', '-c:a', 'libmp3lame', '-b:a', '128k',
        $path,
    );
    return -s $path ? $path : undef;
}

sub cleanup_audio_file ($path) {
    unlink $path if defined $path && -f $path;
}

1;
