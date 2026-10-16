CREATE TABLE user_podcast_subscriptions (
    user_id    BIGINT NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
    feed_id    BIGINT NOT NULL REFERENCES podcast_feeds(id)  ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, feed_id)
);

CREATE INDEX user_podcast_subs_feed_idx ON user_podcast_subscriptions (feed_id);
