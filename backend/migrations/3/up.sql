CREATE TABLE artists (
    id           BIGSERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    sort_name    TEXT,
    mb_id        TEXT UNIQUE,               -- MusicBrainz artist ID
    image_path   TEXT,
    bio          TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX artists_name_lower_idx ON artists (lower(name));
CREATE INDEX artists_sort_name_lower_idx   ON artists (lower(sort_name));
