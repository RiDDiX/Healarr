-- Migration 005: Add media_type support for audio/music files
-- Adds media_type column to corruption_summary and updates the trigger

-- Add media_type column to corruption_summary
ALTER TABLE corruption_summary ADD COLUMN media_type TEXT DEFAULT 'video';

-- Create index for filtering by media type
CREATE INDEX IF NOT EXISTS idx_corruption_summary_media_type ON corruption_summary(media_type);

-- Update existing records: try to extract media_type from events
UPDATE corruption_summary
SET media_type = COALESCE(
    (SELECT json_extract(event_data, '$.media_type') FROM events
     WHERE aggregate_id = corruption_summary.corruption_id
     AND event_type = 'CorruptionDetected'
     LIMIT 1),
    'video'
);

-- Drop and recreate the trigger to include media_type
DROP TRIGGER IF EXISTS trg_update_corruption_summary;

CREATE TRIGGER trg_update_corruption_summary
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
        media_type,
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
            CASE WHEN NEW.event_type = 'CorruptionDetected' THEN json_extract(NEW.event_data, '$.media_type') ELSE NULL END,
            (SELECT media_type FROM corruption_summary WHERE corruption_id = NEW.aggregate_id),
            (SELECT json_extract(event_data, '$.media_type') FROM events
             WHERE aggregate_id = NEW.aggregate_id AND event_type = 'CorruptionDetected' LIMIT 1),
            'video'
        ),
        COALESCE(
            (SELECT detected_at FROM corruption_summary WHERE corruption_id = NEW.aggregate_id),
            NEW.created_at
        ),
        NEW.created_at;
END;

-- Add media_type to scan_paths for path-level configuration
ALTER TABLE scan_paths ADD COLUMN media_type TEXT DEFAULT 'video' CHECK(media_type IN ('video', 'audio', 'all'));
