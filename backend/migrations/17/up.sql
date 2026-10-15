CREATE TABLE radio_stations (
    id           BIGSERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    stream_url   TEXT NOT NULL,
    homepage_url TEXT,
    logo_url     TEXT,
    genre        TEXT,
    bitrate      INTEGER,
    is_public    BOOLEAN NOT NULL DEFAULT TRUE,
    created_by   BIGINT REFERENCES users(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX radio_stations_public_idx ON radio_stations (is_public);
CREATE INDEX radio_stations_name_lower_idx ON radio_stations (lower(name));
