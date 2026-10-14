CREATE TABLE tracks (
    id             BIGSERIAL PRIMARY KEY,
    title          TEXT NOT NULL,
    album_id       BIGINT REFERENCES albums(id)  ON DELETE SET NULL,
    artist_id      BIGINT REFERENCES artists(id) ON DELETE SET NULL,
    track_number   SMALLINT,
    disc_number    SMALLINT,
    duration_ms    INTEGER,                     -- null = unknown
    path           TEXT NOT NULL UNIQUE,        -- absolute path on disk
    file_size      BIGINT,
    mime_type      TEXT,
    codec          TEXT,                        -- e.g. 'flac', 'mp3'
    bitrate        INTEGER,                     -- bits/sec
    sample_rate    INTEGER,                     -- Hz
    channels       SMALLINT,
    mb_id          TEXT UNIQUE,
    search_tsv     TSVECTOR,                    -- filled by trigger below
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX tracks_album_idx      ON tracks (album_id);
CREATE INDEX tracks_artist_idx     ON tracks (artist_id);
CREATE INDEX tracks_title_lower_idx ON tracks (lower(title));

-- Full-text search: weighted (title A, codec C, etc.) — kept simple for v1
CREATE FUNCTION tracks_tsv_update() RETURNS trigger AS $$
BEGIN
    NEW.search_tsv :=
        setweight(to_tsvector('simple', coalesce(NEW.title, '')),  'A');
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER tracks_tsv_trigger
    BEFORE INSERT OR UPDATE OF title ON tracks
    FOR EACH ROW EXECUTE FUNCTION tracks_tsv_update();

CREATE INDEX tracks_search_tsv_idx ON tracks USING GIN (search_tsv);
