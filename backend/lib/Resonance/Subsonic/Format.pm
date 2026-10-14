package Resonance::Subsonic::Format;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(
    subsonic_response subsonic_error
    id_for id_type id_value
    format_artist format_album format_song format_playlist
    format_indexes format_music_folder
);

use constant API_VERSION => '1.16.1';
use constant SERVER_TYPE => 'Resonance';
use constant SERVER_VERSION => '0.01';

# ── envelope ─────────────────────────────────────────────

sub subsonic_response ($payload) {
    return {
        'subsonic-response' => {
            status        => 'ok',
            version       => API_VERSION,
            type          => SERVER_TYPE,
            serverVersion => SERVER_VERSION,
            %$payload,
        },
    };
}

sub subsonic_error ($code, $message) {
    return {
        'subsonic-response' => {
            status        => 'failed',
            version       => API_VERSION,
            type          => SERVER_TYPE,
            serverVersion => SERVER_VERSION,
            error         => {
                code    => 0 + $code,
                message => $message,
            },
        },
    };
}

# ── opaque IDs ───────────────────────────────────────────
# Format: "ar-42", "al-7", "tr-1024", "pl-3"
# Clients treat these as opaque strings.

sub id_for ($type, $id) {
    return "$type-$id";
}

sub id_type ($opaque) {
    return undef unless defined $opaque;
    $opaque =~ /^([a-z]{2})-(\d+)$/ or return undef;
    return $1;
}

sub id_value ($opaque) {
    return undef unless defined $opaque;
    $opaque =~ /^[a-z]{2}-(\d+)$/ or return undef;
    return 0 + $1;
}

# ── entity formatters ────────────────────────────────────

sub _subsonic_time ($iso) {
    return undef unless defined $iso;
    # Subsonic uses ISO 8601. Postgres gives us "2024-01-15 12:34:56+00".
    $iso =~ s/ /T/;
    return $iso;
}

sub format_artist ($row) {
    return {
        id         => id_for('ar', $row->{id}),
        name       => $row->{name},
        albumCount => 0 + ($row->{album_count} // 0),
        coverArt   => defined $row->{cover_album_id}
                      ? id_for('al', $row->{cover_album_id})
                      : undef,
    };
}

sub format_album ($row) {
    my $a = {
        id        => id_for('al', $row->{id}),
        name      => $row->{title},
        artist    => $row->{artist_name},
        artistId  => defined $row->{artist_id} ? id_for('ar', $row->{artist_id}) : undef,
        coverArt  => id_for('al', $row->{id}),
        songCount => 0 + ($row->{song_count} // 0),
        duration  => 0 + ($row->{duration_sec} // 0),
        created   => _subsonic_time($row->{created_at}),
    };
    $a->{year} = 0 + $row->{year} if defined $row->{year};
    return $a;
}

sub format_song ($row) {
    my $s = {
        id          => id_for('tr', $row->{id}),
        title       => $row->{title},
        album       => $row->{album_title},
        albumId     => defined $row->{album_id} ? id_for('al', $row->{album_id}) : undef,
        artist      => $row->{artist_name},
        artistId    => defined $row->{artist_id} ? id_for('ar', $row->{artist_id}) : undef,
        coverArt    => defined $row->{album_id} ? id_for('al', $row->{album_id}) : undef,
        duration    => defined $row->{duration_ms} ? int($row->{duration_ms} / 1000) : 0,
        isDir       => \0,
        contentType => $row->{codec} // 'audio/mpeg',
        suffix      => $row->{codec} // '',
        size        => 0 + ($row->{file_size} // 0),
        path        => $row->{path} // '',
    };
    $s->{track}   = 0 + $row->{track_number} if defined $row->{track_number};
    $s->{discNumber} = 0 + $row->{disc_number} if defined $row->{disc_number};
    $s->{bitRate} = int(($row->{bitrate} // 0) / 1000) if $row->{bitrate};
    $s->{year}    = 0 + $row->{year} if defined $row->{year};
    return $s;
}

sub format_playlist ($row) {
    return {
        id        => id_for('pl', $row->{id}),
        name      => $row->{name},
        comment   => $row->{description},
        owner     => $row->{username},
        public    => $row->{is_public} ? \1 : \0,
        songCount => 0 + ($row->{song_count} // 0),
        duration  => 0 + ($row->{duration_sec} // 0),
        created   => _subsonic_time($row->{created_at}),
    };
}

sub format_music_folder ($id, $name) {
    return { id => $id, name => $name };
}

# ── indexes (for getIndexes) ─────────────────────────────

sub format_indexes ($rows) {
    # Group artists by first letter
    my %by_letter;
    for my $row (@$rows) {
        my $first = uc substr($row->{sort_name} // $row->{name} // '?', 0, 1);
        $first = '#' unless $first =~ /^[A-Z]$/;
        push @{ $by_letter{$first} }, {
            id   => id_for('ar', $row->{id}),
            name => $row->{name},
        };
    }

    my @indexes;
    for my $letter (sort keys %by_letter) {
        push @indexes, {
            name   => $letter,
            artist => $by_letter{$letter},
        };
    }

    # Subsonic calls the "no index" bucket the "lastModified" field.
    return {
        ignoredArticles => 'The El La Los Las Le Les',
        index           => \@indexes,
    };
}

1;
