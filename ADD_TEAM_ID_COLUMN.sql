-- Optional: Add team_id column to event_registrations table
-- This allows registrations to be associated with teams for team-based events
-- Run this in your Supabase SQL Editor only if you need team functionality

-- Add team_id column to event_registrations
ALTER TABLE event_registrations
ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE SET NULL;

-- Create index for team_id lookups
CREATE INDEX IF NOT EXISTS idx_event_registrations_team_id ON event_registrations(team_id);

-- Add comment
COMMENT ON COLUMN event_registrations.team_id IS 'Optional: Team ID for team-based registrations';

-- Verify the column was added
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'event_registrations'
    AND column_name = 'team_id';

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE 'team_id column added successfully to event_registrations table';
    RAISE NOTICE 'You can now use the teamId parameter in registerForEvent() method';
END $$;
