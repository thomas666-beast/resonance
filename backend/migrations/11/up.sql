CREATE TABLE favorites (
    user_id    BIGINT NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    track_id   BIGINT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, track_id)
);

CREATE INDEX favorites_user_created_idx ON favorites (user_id, created_at DESC);
CREATE INDEX favorites_track_idx        ON favorites (track_id);
