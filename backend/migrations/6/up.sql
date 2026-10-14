CREATE TABLE genres (
    id    BIGSERIAL PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE
);

CREATE TABLE tracks_genres (
    track_id  BIGINT NOT NULL REFERENCES tracks(id)  ON DELETE CASCADE,
    genre_id  BIGINT NOT NULL REFERENCES genres(id)  ON DELETE CASCADE,
    PRIMARY KEY (track_id, genre_id)
);

CREATE INDEX tracks_genres_genre_idx ON tracks_genres (genre_id);
