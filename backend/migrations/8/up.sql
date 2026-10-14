CREATE TABLE scan_paths (
    id           BIGSERIAL PRIMARY KEY,
    path         TEXT NOT NULL UNIQUE,
    media_type   TEXT NOT NULL DEFAULT 'music'
                 CHECK (media_type IN ('music', 'video', 'podcast')),
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    last_scan_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
