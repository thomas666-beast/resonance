-- genres.name was created UNIQUE in migration 006, which is case-sensitive.
-- We want case-insensitive uniqueness (Rock / rock / ROCK are one genre).
ALTER TABLE genres DROP CONSTRAINT IF EXISTS genres_name_key;

CREATE UNIQUE INDEX IF NOT EXISTS genres_name_lower_idx
    ON genres (lower(name));

-- tracks_genres already exists from migration 006 with PK (track_id, genre_id).
-- Add an index on genre_id for reverse lookups (list tracks by genre).
CREATE INDEX IF NOT EXISTS tracks_genres_genre_idx
    ON tracks_genres (genre_id);
