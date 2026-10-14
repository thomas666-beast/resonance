package Resonance::Job::Scan;
use Mojo::Base -strict, -signatures;

use File::Find::Rule;
use Audio::Scan;
use Resonance::Scan::Normalizer qw(normalize_tags normalize_info);

# Our v1 supported extensions
my @EXTENSIONS = qw(*.flac *.mp3 *.m4a *.ogg *.opus);

sub register ($minion) {
    $minion->add_task(scan => sub ($job, $scan_path_id) {
        my $app = $job->app;
        my $pg  = $app->pg;
        my $redis = $app->redis;

        my $scan_path = $pg->db->query(
            'SELECT id, path, media_type FROM scan_paths WHERE id = ?',
            $scan_path_id,
        )->hash;

        unless ($scan_path) {
            $job->fail("scan_path $scan_path_id not found");
            return;
        }

        my $root = $scan_path->{path};
        unless (-d $root) {
            $job->fail("scan path not a directory: $root");
            return;
        }

        my @files = File::Find::Rule->file()
            ->name(@EXTENSIONS)
            ->not(File::Find::Rule->new->name(qr/^\./))
            ->in($root);

        my $total = scalar @files;
        $app->log->info("Scan started: $total files under $root");

        $job->note(total => $total);
        $redis->pubsub->notify('resonance:scan', {
            event => 'started',
            scan_path_id => $scan_path_id,
            total => $total,
        });

        my $processed = 0;
        my $inserted  = 0;
        my $updated   = 0;
        my $failed    = 0;

        for my $file (@files) {
            my $result = eval { _process_file($app, $file, $scan_path_id) };
            if ($@) {
                $failed++;
                $app->log->warn("Scan failed on $file: $@");
            } else {
                $result->{inserted} ? $inserted++ : $updated++;
            }

            $processed++;

            # Progress every 50 files
            if ($processed % 50 == 0) {
                $job->note(processed => $processed);
                $redis->pubsub->notify('resonance:scan', {
                    event => 'progress',
                    scan_path_id => $scan_path_id,
                    processed => $processed,
                    total => $total,
                });
            }
        }

        $pg->db->query(
            'UPDATE scan_paths SET last_scan_at = now() WHERE id = ?',
            $scan_path_id,
        );

        $redis->pubsub->notify('resonance:scan', {
            event => 'finished',
            scan_path_id => $scan_path_id,
            total => $total,
            inserted => $inserted,
            updated => $updated,
            failed => $failed,
        });

        $job->finish({
            total => $total,
            inserted => $inserted,
            updated => $updated,
            failed => $failed,
        });
    });
}

sub _process_file ($app, $file, $scan_path_id) {
    my $raw = Audio::Scan->scan($file);
    my $tags = normalize_tags($raw->{tags});
    my $info = normalize_info($raw->{info});

    my $title = $tags->{title} // _basename_no_ext($file);

    # Upsert artist
    my $artist_id;
    if (my $name = $tags->{artist}) {
        my $existing_artist = $app->pg->db->query(
            'SELECT id FROM artists WHERE lower(name) = lower(?)',
            $name,
        )->hash;

        if ($existing_artist) {
            $artist_id = $existing_artist->{id};
        }
        else {
            $artist_id = $app->pg->db->query(
                'INSERT INTO artists (name) VALUES (?) RETURNING id',
                $name,
            )->hash->{id};
        }
    }

    # Upsert album
    my $album_id;
    if (my $album_title = $tags->{album}) {
        my $existing_album = $app->pg->db->query(
            'SELECT id FROM albums WHERE lower(title) = lower(?) AND artist_id IS NOT DISTINCT FROM ?',
            $album_title, $artist_id,
        )->hash;

        if ($existing_album) {
            $album_id = $existing_album->{id};
        }
        else {
            $album_id = $app->pg->db->query(
                'INSERT INTO albums (title, artist_id) VALUES (?, ?) RETURNING id',
                $album_title, $artist_id,
            )->hash->{id};
        }
    }

    # Upsert track
    my $existing = $app->pg->db->query(
        'SELECT id FROM tracks WHERE path = ?', $file,
    )->hash;

    my $track_id;
    if ($existing) {
        $app->pg->db->query(
            q{UPDATE tracks SET title = ?, album_id = ?, artist_id = ?,
              track_number = ?, disc_number = ?, duration_ms = ?,
              bitrate = ?, sample_rate = ?, channels = ?,
              mime_type = ?, updated_at = now()
              WHERE id = ?},
            $title, $album_id, $artist_id,
            $tags->{track_number}, $tags->{disc_number}, $info->{duration_ms},
            $info->{bitrate}, $info->{sample_rate}, $info->{channels},
            $info->{codec}, $existing->{id},
        );
        $track_id = $existing->{id};
    } else {
        $track_id = $app->pg->db->query(
            q{INSERT INTO tracks (title, album_id, artist_id,
              track_number, disc_number, duration_ms, bitrate,
              sample_rate, channels, path, mime_type, file_size)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              RETURNING id},
            $title, $album_id, $artist_id,
            $tags->{track_number}, $tags->{disc_number}, $info->{duration_ms},
            $info->{bitrate}, $info->{sample_rate}, $info->{channels},
            $file, $info->{codec}, -s $file,
        )->hash->{id};
    }

    return { inserted => !$existing, track_id => $track_id };
}

sub _basename_no_ext ($file) {
    my $base = $file;
    $base =~ s{.*/}{};
    $base =~ s{\.[^.]+$}{};
    return $base;
}

1;
