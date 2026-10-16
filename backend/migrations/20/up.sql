CREATE TABLE podcast_progress (
    user_id      BIGINT NOT NULL REFERENCES users(id)             ON DELETE CASCADE,
    episode_id   BIGINT NOT NULL REFERENCES podcast_episodes(id)  ON DELETE CASCADE,
    position_sec INTEGER NOT NULL DEFAULT 0,
    duration_sec INTEGER,
    completed    BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, episode_id)
);

CREATE INDEX podcast_progress_updated_idx ON podcast_progress (user_id, updated_at DESC);
