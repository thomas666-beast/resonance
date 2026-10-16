package Resonance::Job::Scan;
use Mojo::Base -strict, -signatures;

use File::Find::Rule;
use Audio::Scan;
use Mojo::File qw(path);
use Resonance::Scan::Normalizer qw(normalize_tags normalize_info);

# Our v1 supported extensions
my @EXTENSIONS = qw(*.flac *.mp3 *.m4a *.ogg *.opus);

sub register ($minion) {
    $minion->add_task(scan => sub ($job, $scan_path_id) {
        my $app   = $job->app;
        my $pg    = $app->pg;
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
            event        => 'started',
            scan_path_id => $scan_path_id,
            total        => $total,
        });

        my $processed = 0;
        my $inserted  = 0;
        my $updated   = 0;
        my $failed    = 0;

        # Track which paths we saw, so reconciliation can diff
        my %seen;
        for my $file (@files) { $seen{$file} = 1 }

        for my $file (@files) {
            my $result = eval { _process_file($app, $file, $scan_path_id) };
            if ($@) {
                $failed++;
                $app->log->warn("Scan failed on $file: $@");
            } else {
                $result->{inserted} ? $inserted++ : $updated++;
            }

            $processed++;

            if ($processed % 50 == 0) {
                $job->note(processed => $processed);
                $redis->pubsub->notify('resonance:scan', {
                    event        => 'progress',
                    scan_path_id => $scan_path_id,
                    processed    => $processed,
                    total        => $total,
                });
            }
        }

        # ── reconciliation phase ────────────────────────
        # Publish a phase-change so the UI can switch labels.
        $redis->pubsub->notify('resonance:scan', {
            event        => 'reconciling',
            scan_path_id => $scan_path_id,
        });

        my ($missing, $restored) = _reconcile($app, $root, \%seen);

        $pg->db->query(
            'UPDATE scan_paths SET last_scan_at = now() WHERE id = ?',
            $scan_path_id,
        );

        $redis->pubsub->notify('resonance:scan', {
            event        => 'finished',
            scan_path_id => $scan_path_id,
            total        => $total,
            inserted     => $inserted,
            updated      => $updated,
            failed       => $failed,
            missing      => $missing,
            restored     => $restored,
        });

        $job->finish({
            total     => $total,
            inserted  => $inserted,
            updated   => $updated,
            failed    => $failed,
            missing   => $missing,
            restored  => $restored,
        });
    });
}

# ── reconciliation ───────────────────────────────────────

sub _reconcile ($app, $root, $seen) {
    my $db = $app->pg->db;

    # Range scan on path uses the B-tree index:
    #   path >= 'root/' AND path < 'root0'
    # where 'root0' is the next string after 'root/' in lexicographic order.
    my $prefix = $root;
    $prefix =~ s{/$}{};
    $prefix .= '/';
    my $upper = $prefix;
    $upper =~ s{/$}{0};

    # Tracks in DB under this root that are currently NOT missing
    my $in_db = $db->query(
        q{SELECT id, path FROM tracks
           WHERE path >= ? AND path < ?
             AND missing_at IS NULL},
        $prefix, $upper,
    )->hashes->to_array;

    # Tracks in DB under this root that ARE currently marked missing
    my $in_db_missing = $db->query(
        q{SELECT id, path FROM tracks
           WHERE path >= ? AND path < ?
             AND missing_at IS NOT NULL},
        $prefix, $upper,
    )->hashes->to_array;

    my @now_missing;
    for my $row (@$in_db) {
        push @now_missing, $row->{id} unless $seen->{ $row->{path} };
    }

    my @now_present;
    for my $row (@$in_db_missing) {
        push @now_present, $row->{id} if $seen->{ $row->{path} };
    }

    if (@now_missing) {
        $db->query(
            'UPDATE tracks SET missing_at = now() WHERE id = ANY(?)',
            \@now_missing,
        );
        $app->log->info("Reconcile: marked " . scalar(@now_missing) . " tracks as missing");
    }

    if (@now_present) {
        $db->query(
            'UPDATE tracks SET missing_at = NULL WHERE id = ANY(?)',
            \@now_present,
        );
        $app->log->info("Reconcile: restored " . scalar(@now_present) . " tracks");
    }

    return (scalar @now_missing, scalar @now_present);
}

# ── file processing (unchanged) ──────────────────────────

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

    if ($album_id) {
        eval { _ensure_album_cover($app, $album_id, $raw, $file) };
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
              mime_type = ?, missing_at = NULL, updated_at = now()
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

    # Sync genres (split multi-genre tags into separate rows)
    _sync_track_genres($app, $track_id, $tags->{genre});

    return { inserted => !$existing, track_id => $track_id };
}

sub _basename_no_ext ($file) {
    my $base = $file;
    $base =~ s{.*/}{};
    $base =~ s{\.[^.]+$}{};
    return $base;
}

# ── cover extraction ─────────────────────────────────────

sub _cover_cache_dir ($app) {
    my $dir = $app->config->{cover_cache_dir} // 'data/covers';
    path($dir)->make_path unless -d $dir;
    return $dir;
}

sub _extract_embedded_cover ($raw) {
    if (my $apic = $raw->{tags}{APIC}) {
        my $arr = ref $apic eq 'ARRAY' ? $apic : [$apic];
        if (@$arr >= 4 && defined $arr->[3] && !ref $arr->[3]) {
            return $arr->[3];
        }
        for my $entry (@$arr) {
            if (ref $entry eq 'HASH' && defined $entry->{data}) {
                return $entry->{data};
            }
        }
    }

    if (my $pic = $raw->{info}{PICTURE}) {
        my $arr = ref $pic eq 'ARRAY' ? $pic : [$pic];
        for my $entry (@$arr) {
            if (ref $entry eq 'HASH' && defined $entry->{data}) {
                return $entry->{data};
            }
            return $entry if !ref $entry;
        }
    }

    if (my $covr = $raw->{tags}{COVR}) {
        my $data = ref $covr eq 'ARRAY' ? $covr->[0] : $covr;
        return $data if defined $data && !ref $data;
    }

    return undef;
}

sub _find_folder_cover ($file) {
    my $dir = path($file)->dirname;
    for my $name (qw/cover.jpg cover.jpeg cover.png folder.jpg folder.png front.jpg front.png/) {
        my $candidate = $dir->child($name);
        return $candidate->to_string if -f $candidate;
    }
    return undef;
}

sub _ensure_album_cover ($app, $album_id, $raw, $file) {
    my $existing = $app->pg->db->query(
        'SELECT cover_path FROM albums WHERE id = ?', $album_id,
    )->hash->{cover_path};
    return if defined $existing && length $existing;

    my $dir = _cover_cache_dir($app);

    my $bytes = _extract_embedded_cover($raw);
    if (defined $bytes && length $bytes) {
        my $out = "$dir/$album_id.jpg";
        path($out)->spurt($bytes);
        $app->pg->db->query(
            'UPDATE albums SET cover_path = ?, updated_at = now() WHERE id = ?',
            $out, $album_id,
        );
        return;
    }

    my $src = _find_folder_cover($file);
    if ($src) {
        my $out = "$dir/$album_id.jpg";
        path($src)->copy_to($out);
        $app->pg->db->query(
            'UPDATE albums SET cover_path = ?, updated_at = now() WHERE id = ?',
            $out, $album_id,
        );
        return;
    }
}

# ── genre indexing ───────────────────────────────────────

sub _sync_track_genres ($app, $track_id, $genre_string) {
    return unless $track_id;

    my $db = $app->pg->db;

    # Remove the previous genre links for this track, then rebuild from
    # the current tag. A rescan reflects any tag changes cleanly.
    $db->query('DELETE FROM tracks_genres WHERE track_id = ?', $track_id);

    return unless defined $genre_string && length $genre_string;

    # The normalizer returns a comma-joined string; split into parts.
    my %seen;
    my @genres;
    for my $part (split /,/, $genre_string) {
        $part =~ s/^\s+|\s+$//g;
        next unless length $part;
        next unless length $part <= 100;  # guard against pathological tags
        my $key = lc $part;
        next if $seen{$key}++;
        push @genres, $part;
    }

    return unless @genres;

    for my $name (@genres) {
        # Upsert the genre row. The unique index is on lower(name).
        my $genre_id = $db->query(
            q{INSERT INTO genres (name) VALUES (?)
              ON CONFLICT (lower(name)) DO UPDATE SET name = genres.name
              RETURNING id},
            $name,
        )->hash->{id};

        $db->query(
            q{INSERT INTO tracks_genres (track_id, genre_id)
              VALUES (?, ?) ON CONFLICT DO NOTHING},
            $track_id, $genre_id,
        );
    }
}

1;
