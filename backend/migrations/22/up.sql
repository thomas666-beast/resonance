CREATE TABLE track_lyrics (
    track_id   BIGINT PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
    source     TEXT NOT NULL CHECK (source IN ('lrc', 'lrclib', 'manual')),
    synced     BOOLEAN NOT NULL DEFAULT FALSE,
    content    TEXT NOT NULL,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
