CREATE TABLE albums (
    id           BIGSERIAL PRIMARY KEY,
    title        TEXT NOT NULL,
    artist_id    BIGINT REFERENCES artists(id) ON DELETE SET NULL,
    year         SMALLINT,
    mb_id        TEXT UNIQUE,
    cover_path   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX albums_artist_idx           ON albums (artist_id);
CREATE INDEX albums_title_lower_idx      ON albums (lower(title));
