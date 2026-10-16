-- Podcast feeds (a show you've subscribed to)
CREATE TABLE podcast_feeds (
    id              BIGSERIAL PRIMARY KEY,
    feed_url        TEXT NOT NULL UNIQUE,
    title           TEXT,
    description     TEXT,
    website_url     TEXT,
    image_url       TEXT,
    author          TEXT,
    language        TEXT,
    itunes_id       BIGINT,
    last_fetched_at TIMESTAMPTZ,
    last_error      TEXT,
    created_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX podcast_feeds_created_by_idx ON podcast_feeds (created_by);

-- Individual episodes
CREATE TABLE podcast_episodes (
    id              BIGSERIAL PRIMARY KEY,
    feed_id         BIGINT NOT NULL REFERENCES podcast_feeds(id) ON DELETE CASCADE,
    guid            TEXT NOT NULL,
    title           TEXT NOT NULL,
    description     TEXT,
    audio_url       TEXT NOT NULL,
    duration_sec    INTEGER,
    published_at    TIMESTAMPTZ,
    image_url       TEXT,
    episode_number  INTEGER,
    season_number   INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- GUID is stable across feed refreshes; the unique constraint
-- prevents duplicates when re-fetching
CREATE UNIQUE INDEX podcast_episodes_feed_guid_idx
    ON podcast_episodes (feed_id, guid);

CREATE INDEX podcast_episodes_feed_published_idx
    ON podcast_episodes (feed_id, published_at DESC NULLS LAST);
