-- ============================================
-- ADD MISSING COLUMNS TO MESSAGES TABLE
-- ============================================

-- The error: "Could not find the 'message_type' column of 'messages'"
-- This means your messages table is missing some columns that the app expects.

-- STEP 1: Check current structure of messages table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'messages'
ORDER BY ordinal_position;

-- STEP 2: Add missing columns

-- Add message_type column (text, image, file, video)
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS message_type text DEFAULT 'text' NOT NULL;

-- Add file_url column (for images/files/videos)
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS file_url text;

-- Add is_read column (for read receipts)
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false NOT NULL;

-- STEP 3: Verify columns were added
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'messages'
ORDER BY ordinal_position;

-- STEP 4: Reload Supabase schema cache
-- This tells Supabase to refresh its understanding of the table structure
NOTIFY pgrst, 'reload schema';

-- ============================================
-- EXPECTED COLUMNS IN MESSAGES TABLE:
-- ============================================
-- id (uuid)
-- room_id (uuid)
-- sender_id (uuid)
-- content (text)
-- message_type (text) - NEW!
-- file_url (text) - NEW!
-- is_read (boolean) - NEW!
-- created_at (timestamp)
-- updated_at (timestamp)
-- ============================================

-- SUCCESS! Now hot restart your app and try sending a message.
