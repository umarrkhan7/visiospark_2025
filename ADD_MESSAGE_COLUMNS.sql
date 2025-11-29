-- =====================================================
-- ADD MESSAGE COLUMNS TO MESSAGES TABLE
-- =====================================================
-- Purpose: Add missing columns to messages table for
--          proper message functionality
-- Date: November 29, 2025
-- Status: PENDING EXECUTION
-- =====================================================

-- Add message_type column (text, image, file, etc.)
ALTER TABLE messages 
  ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';

-- Add file_url column for attachments
ALTER TABLE messages 
  ADD COLUMN IF NOT EXISTS file_url TEXT;

-- Add is_read column for read receipts
ALTER TABLE messages 
  ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;

-- Add comment for documentation
COMMENT ON COLUMN messages.message_type IS 'Type of message: text, image, file, audio, video';
COMMENT ON COLUMN messages.file_url IS 'URL to uploaded file/image if message contains attachment';
COMMENT ON COLUMN messages.is_read IS 'Whether the message has been read by recipient';

-- Verify columns were added
DO $$ 
BEGIN
  RAISE NOTICE 'Checking messages table columns...';
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'messages' 
    AND column_name = 'message_type'
  ) THEN
    RAISE NOTICE '✓ message_type column exists';
  ELSE
    RAISE EXCEPTION '✗ message_type column missing!';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'messages' 
    AND column_name = 'file_url'
  ) THEN
    RAISE NOTICE '✓ file_url column exists';
  ELSE
    RAISE EXCEPTION '✗ file_url column missing!';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'messages' 
    AND column_name = 'is_read'
  ) THEN
    RAISE NOTICE '✓ is_read column exists';
  ELSE
    RAISE EXCEPTION '✗ is_read column missing!';
  END IF;
  
  RAISE NOTICE '✓ All columns added successfully!';
END $$;

-- Optional: Create index on is_read for faster unread count queries
CREATE INDEX IF NOT EXISTS idx_messages_is_read 
  ON messages(room_id, is_read) 
  WHERE is_read = false;

COMMENT ON INDEX idx_messages_is_read IS 'Fast lookup for unread messages per room';

-- Optional: Create function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_as_read(
  p_room_id UUID,
  p_user_id UUID
)
RETURNS INTEGER AS $$
DECLARE
  affected_count INTEGER;
BEGIN
  UPDATE messages
  SET is_read = true
  WHERE room_id = p_room_id
    AND sender_id != p_user_id
    AND is_read = false;
  
  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RETURN affected_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION mark_messages_as_read IS 'Mark all unread messages in a room as read for current user';

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'MESSAGE COLUMNS SETUP COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Added columns:';
  RAISE NOTICE '  - message_type (TEXT)';
  RAISE NOTICE '  - file_url (TEXT)';
  RAISE NOTICE '  - is_read (BOOLEAN)';
  RAISE NOTICE '';
  RAISE NOTICE 'Created index:';
  RAISE NOTICE '  - idx_messages_is_read';
  RAISE NOTICE '';
  RAISE NOTICE 'Created function:';
  RAISE NOTICE '  - mark_messages_as_read()';
  RAISE NOTICE '';
  RAISE NOTICE '✓ You can now send messages!';
  RAISE NOTICE '';
END $$;
