-- ============================================
-- ULTIMATE FIX: Use security definer function to break recursion
-- ============================================

-- The problem: Even our "simple" policies still have recursion because
-- view_chat_participants checks chat_participants within itself.
-- Solution: Use a security definer function that bypasses RLS.

-- STEP 1: Drop all existing policies again
DROP POLICY IF EXISTS "view_own_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "create_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "update_own_chat_rooms" ON chat_rooms;

DROP POLICY IF EXISTS "view_chat_participants" ON chat_participants;
DROP POLICY IF EXISTS "add_chat_participants" ON chat_participants;

DROP POLICY IF EXISTS "view_messages" ON messages;
DROP POLICY IF EXISTS "send_messages" ON messages;
DROP POLICY IF EXISTS "Users can send messages to their rooms" ON messages;
DROP POLICY IF EXISTS "update_own_messages" ON messages;
DROP POLICY IF EXISTS "mark_messages_read" ON messages;

-- STEP 2: Create a helper function that bypasses RLS
CREATE OR REPLACE FUNCTION public.get_user_room_ids(user_uuid uuid)
RETURNS TABLE (room_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT cp.room_id
  FROM chat_participants cp
  WHERE cp.user_id = user_uuid;
END;
$$;

-- STEP 3: Create simple policies using the helper function

-- ============================================
-- CHAT ROOMS POLICIES
-- ============================================

CREATE POLICY "view_own_chat_rooms"
ON chat_rooms
FOR SELECT
USING (
  created_by = auth.uid() OR
  id IN (SELECT * FROM get_user_room_ids(auth.uid()))
);

CREATE POLICY "create_chat_rooms"
ON chat_rooms
FOR INSERT
WITH CHECK (auth.uid() = created_by);

CREATE POLICY "update_own_chat_rooms"
ON chat_rooms
FOR UPDATE
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- ============================================
-- CHAT PARTICIPANTS POLICIES (NO RECURSION!)
-- ============================================

-- Simple policy: users can view themselves and others in same room
CREATE POLICY "view_chat_participants"
ON chat_participants
FOR SELECT
USING (
  user_id = auth.uid() OR
  room_id IN (SELECT * FROM get_user_room_ids(auth.uid()))
);

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

CREATE POLICY "view_messages"
ON messages
FOR SELECT
USING (
  room_id IN (SELECT * FROM get_user_room_ids(auth.uid()))
);

CREATE POLICY "send_messages"
ON messages
FOR INSERT
WITH CHECK (
  sender_id = auth.uid() AND
  room_id IN (SELECT * FROM get_user_room_ids(auth.uid()))
);

CREATE POLICY "update_own_messages"
ON messages
FOR UPDATE
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

CREATE POLICY "mark_messages_read"
ON messages
FOR UPDATE
USING (
  room_id IN (SELECT * FROM get_user_room_ids(auth.uid()))
);

-- ============================================
-- STEP 4: Test the function works
-- ============================================

-- Test: Get your room IDs (should return empty if you have no chats yet)
SELECT * FROM get_user_room_ids(auth.uid());

-- ============================================
-- STEP 5: Verify policies
-- ============================================
SELECT 
  tablename,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename IN ('chat_rooms', 'chat_participants', 'messages')
ORDER BY tablename, cmd;

-- ============================================
-- SUCCESS! No more recursion!
-- The security definer function runs with elevated privileges
-- and doesn't trigger RLS checks, breaking the recursive loop.
-- ============================================
