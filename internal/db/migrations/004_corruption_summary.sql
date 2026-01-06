-- Migration 004: Add corruption_summary materialized table
-- Replaces the slow corruption_status VIEW with a trigger-maintained table
-- for dramatically improved query performance (O(1) vs O(n*m) for status lookups)

-- Create the corruption_summary table
CREATE TABLE IF NOT EXISTS corruption_summary (
    corruption_id TEXT PRIMARY KEY,
    current_state TEXT NOT NULL,
    retry_count INTEGER DEFAULT 0,
    file_path TEXT,
    path_id INTEGER,
    last_error TEXT,
    corruption_type TEXT,
    detected_at TIMESTAMP,
    last_updated_at TIMESTAMP
);

-- Create indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_corruption_summary_state ON corruption_summary(current_state);
CREATE INDEX IF NOT EXISTS idx_corruption_summary_path_id ON corruption_summary(path_id);
CREATE INDEX IF NOT EXISTS idx_corruption_summary_detected_at ON corruption_summary(detected_at);

-- Populate initial data from existing events
INSERT OR REPLACE INTO corruption_summary (
    corruption_id,
    current_state,
    retry_count,
    file_path,
    path_id,
    last_error,
    corruption_type,
    detected_at,
    last_updated_at
)
SELECT
    aggregate_id as corruption_id,
    (SELECT event_type FROM events e2
     WHERE e2.aggregate_id = e.aggregate_id
     ORDER BY id DESC LIMIT 1) as current_state,
    (SELECT COUNT(*) FROM events e3
     WHERE e3.aggregate_id = e.aggregate_id
     AND e3.event_type LIKE '%Failed') as retry_count,
    (SELECT json_extract(event_data, '$.file_path') FROM events e4
     WHERE e4.aggregate_id = e.aggregate_id
     AND e4.event_type = 'CorruptionDetected'
     LIMIT 1) as file_path,
    (SELECT json_extract(event_data, '$.path_id') FROM events e7
     WHERE e7.aggregate_id = e.aggregate_id
     AND e7.event_type = 'CorruptionDetected'
     LIMIT 1) as path_id,
    (SELECT json_extract(event_data, '$.error') FROM events e5
     WHERE e5.aggregate_id = e.aggregate_id
     ORDER BY id DESC LIMIT 1) as last_error,
    (SELECT json_extract(event_data, '$.corruption_type') FROM events e6
     WHERE e6.aggregate_id = e.aggregate_id
     AND e6.event_type = 'CorruptionDetected'
     LIMIT 1) as corruption_type,
    MIN(created_at) as detected_at,
    MAX(created_at) as last_updated_at
FROM events e
WHERE aggregate_type = 'corruption'
GROUP BY aggregate_id;

-- Create trigger to maintain corruption_summary on event inserts
CREATE TRIGGER IF NOT EXISTS trg_update_corruption_summary
AFTER INSERT ON events
WHEN NEW.aggregate_type = 'corruption'
BEGIN
    INSERT OR REPLACE INTO corruption_summary (
        corruption_id,
        current_state,
        retry_count,
        file_path,
        path_id,
        last_error,
        corruption_type,
        detected_at,
        last_updated_at
    )
    SELECT
        NEW.aggregate_id,
        NEW.event_type,
        (SELECT COUNT(*) FROM events WHERE aggregate_id = NEW.aggregate_id AND event_type LIKE '%Failed'),
        COALESCE(
            CASE WHEN NEW.event_type = 'CorruptionDetected' THEN json_extract(NEW.event_data, '$.file_path') ELSE NULL END,
            (SELECT file_path FROM corruption_summary WHERE corruption_id = NEW.aggregate_id),
            (SELECT json_extract(event_data, '$.file_path') FROM events
             WHERE aggregate_id = NEW.aggregate_id AND event_type = 'CorruptionDetected' LIMIT 1)
        ),
        COALESCE(
            CASE WHEN NEW.event_type = 'CorruptionDetected' THEN json_extract(NEW.event_data, '$.path_id') ELSE NULL END,
            (SELECT path_id FROM corruption_summary WHERE corruption_id = NEW.aggregate_id),
            (SELECT json_extract(event_data, '$.path_id') FROM events
             WHERE aggregate_id = NEW.aggregate_id AND event_type = 'CorruptionDetected' LIMIT 1)
        ),
        json_extract(NEW.event_data, '$.error'),
        COALESCE(
            CASE WHEN NEW.event_type = 'CorruptionDetected' THEN json_extract(NEW.event_data, '$.corruption_type') ELSE NULL END,
            (SELECT corruption_type FROM corruption_summary WHERE corruption_id = NEW.aggregate_id),
            (SELECT json_extract(event_data, '$.corruption_type') FROM events
             WHERE aggregate_id = NEW.aggregate_id AND event_type = 'CorruptionDetected' LIMIT 1)
        ),
        COALESCE(
            (SELECT detected_at FROM corruption_summary WHERE corruption_id = NEW.aggregate_id),
            NEW.created_at
        ),
        NEW.created_at;
END;
