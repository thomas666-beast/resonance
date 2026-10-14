CREATE TABLE api_tokens (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name         TEXT NOT NULL,             -- human label, e.g. "phone", "laptop"
    token_hash   TEXT NOT NULL UNIQUE,      -- sha256 of the actual token
    scopes       TEXT[] NOT NULL DEFAULT ARRAY['read']::TEXT[],
    last_used_at TIMESTAMPTZ,
    expires_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX api_tokens_user_idx ON api_tokens (user_id);
