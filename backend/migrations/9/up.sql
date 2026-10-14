-- Fuzzy search on track/artist/album names (pg_trgm)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX tracks_title_trgm_idx  ON tracks  USING GIN (lower(title)  gin_trgm_ops);
CREATE INDEX artists_name_trgm_idx  ON artists USING GIN (lower(name)   gin_trgm_ops);
CREATE INDEX albums_title_trgm_idx  ON albums  USING GIN (lower(title)  gin_trgm_ops);
