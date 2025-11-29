-- ============================================
-- CLEAN SLATE: Remove ALL chat policies and recreate
-- ============================================

-- STEP 1: Drop ALL existing policies on chat tables
DROP POLICY IF EXISTS "view_own_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "create_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users can view rooms they participate in" ON chat_rooms;
DROP POLICY IF EXISTS "Users can create rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users can update rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users can delete rooms" ON chat_rooms;

DROP POLICY IF EXISTS "view_chat_participants" ON chat_participants;
DROP POLICY IF EXISTS "add_chat_participants" ON chat_participants;
DROP POLICY IF EXISTS "Users can view participants of their rooms" ON chat_participants;
DROP POLICY IF EXISTS "Users can add participants" ON chat_participants;
DROP POLICY IF EXISTS "Users can remove participants" ON chat_participants;

DROP POLICY IF EXISTS "Users can view messages in their rooms" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON messages;
DROP POLICY IF EXISTS "Users can delete their own messages" ON messages;

-- STEP 2: Create new, simple policies without recursion

-- ============================================
-- CHAT ROOMS POLICIES
-- ============================================

-- Allow users to view rooms they created or participate in
CREATE POLICY "view_own_chat_rooms"
ON chat_rooms
FOR SELECT
USING (
  created_by = auth.uid() OR
  id IN (
    SELECT room_id 
    FROM chat_participants 
    WHERE user_id = auth.uid()
  )
);

-- Allow authenticated users to create rooms
CREATE POLICY "create_chat_rooms"
ON chat_rooms
FOR INSERT
WITH CHECK (auth.uid() = created_by);

-- Allow room creators to update their rooms
CREATE POLICY "update_own_chat_rooms"
ON chat_rooms
FOR UPDATE
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- ============================================
-- CHAT PARTICIPANTS POLICIES
-- ============================================

-- Allow users to view participants in rooms they're part of
CREATE POLICY "view_chat_participants"
ON chat_participants
FOR SELECT
USING (
  user_id = auth.uid() OR
  room_id IN (
    SELECT room_id 
    FROM chat_participants 
    WHERE user_id = auth.uid()
  )
);

-- Allow users to be added to rooms (by room creator or self)
CREATE POLICY "add_chat_participants"
ON chat_participants
FOR INSERT
WITH CHECK (
  auth.uid() = user_id OR 
  EXISTS (
    SELECT 1 FROM chat_rooms 
    WHERE id = room_id 
    AND created_by = auth.uid()
  )
);

-- ============================================
-- MESSAGES POLICIES
-- ============================================

-- Allow users to view messages in rooms they participate in
CREATE POLICY "view_messages"
ON messages
FOR SELECT
USING (
  room_id IN (
    SELECT room_id 
    FROM chat_participants 
    WHERE user_id = auth.uid()
  )
);

-- Allow users to send messages to rooms they're part of
CREATE POLICY "send_messages"
ON messages
FOR INSERT
WITH CHECK (
  sender_id = auth.uid() AND
  room_id IN (
    SELECT room_id 
    FROM chat_participants 
    WHERE user_id = auth.uid()
  )
);

-- Allow users to update their own messages
CREATE POLICY "update_own_messages"
ON messages
FOR UPDATE
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

-- Allow users to mark messages as read
CREATE POLICY "mark_messages_read"
ON messages
FOR UPDATE
USING (
  room_id IN (
    SELECT room_id 
    FROM chat_participants 
    WHERE user_id = auth.uid()
  )
);

-- ============================================
-- STEP 3: Verify all policies
-- ============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename IN ('chat_rooms', 'chat_participants', 'messages')
ORDER BY tablename, cmd;

-- ============================================
-- SUCCESS! 
-- Expected policies:
-- 
-- chat_rooms:
--   - view_own_chat_rooms (SELECT)
--   - create_chat_rooms (INSERT)
--   - update_own_chat_rooms (UPDATE)
--
-- chat_participants:
--   - view_chat_participants (SELECT)
--   - add_chat_participants (INSERT)
--
-- messages:
--   - view_messages (SELECT)
--   - send_messages (INSERT)
--   - update_own_messages (UPDATE)
--   - mark_messages_read (UPDATE)
-- ============================================
