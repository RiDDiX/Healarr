-- Migration 006: Add Lidarr support
-- Extends arr_instances type constraint to include 'lidarr'

-- SQLite doesn't support ALTER TABLE to modify CHECK constraints
-- We need to recreate the table with the new constraint
-- Note: Foreign keys are disabled during migrations (enabled after in repository.go)

-- Step 1: Create temporary table with new constraint
CREATE TABLE arr_instances_new (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('sonarr', 'radarr', 'whisparr-v2', 'whisparr-v3', 'lidarr')),
    url TEXT NOT NULL,
    api_key TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Step 2: Copy data from old table
INSERT INTO arr_instances_new (id, name, type, url, api_key, enabled, created_at, updated_at)
SELECT id, name, type, url, api_key, enabled, created_at, updated_at FROM arr_instances;

-- Step 3: Drop old table
DROP TABLE arr_instances;

-- Step 4: Rename new table to original name
ALTER TABLE arr_instances_new RENAME TO arr_instances;
