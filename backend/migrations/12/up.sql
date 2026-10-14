CREATE TABLE user_plays (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    track_id   BIGINT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    played_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX user_plays_user_time_idx ON user_plays (user_id, played_at DESC);
CREATE INDEX user_plays_track_idx     ON user_plays (track_id);
