ALTER TABLE tracks ADD COLUMN missing_at TIMESTAMPTZ;

-- Partial index so "find missing tracks" is fast, but the regular
-- queries (WHERE missing_at IS NULL) don't pay for it.
CREATE INDEX tracks_missing_at_idx ON tracks (missing_at)
    WHERE missing_at IS NOT NULL;

-- Composite index for the reconciliation query: find all non-missing
-- tracks under a given path prefix. Uses a range scan on path.
CREATE INDEX tracks_path_active_idx ON tracks (path)
    WHERE missing_at IS NULL;
