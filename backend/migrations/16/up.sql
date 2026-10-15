ALTER TABLE albums ADD COLUMN parent_id BIGINT REFERENCES albums(id) ON DELETE SET NULL;
CREATE INDEX albums_parent_idx ON albums (parent_id);
