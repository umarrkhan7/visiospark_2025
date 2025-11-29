-- ============================================
-- FORUM VOTING SYSTEM SETUP
-- ============================================

-- STEP 1: Check if votes table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_name = 'votes'
);

-- STEP 2: Create votes table if it doesn't exist
CREATE TABLE IF NOT EXISTS votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  post_id uuid REFERENCES forum_posts(id) ON DELETE CASCADE,
  comment_id uuid REFERENCES forum_comments(id) ON DELETE CASCADE,
  vote_type text NOT NULL CHECK (vote_type IN ('up', 'down')),
  created_at timestamp with time zone DEFAULT now(),
  
  -- Ensure user can only vote once per post or comment
  CONSTRAINT unique_user_post_vote UNIQUE (user_id, post_id),
  CONSTRAINT unique_user_comment_vote UNIQUE (user_id, comment_id),
  
  -- Ensure either post_id or comment_id is set, but not both
  CONSTRAINT vote_target_check CHECK (
    (post_id IS NOT NULL AND comment_id IS NULL) OR
    (post_id IS NULL AND comment_id IS NOT NULL)
  )
);

-- STEP 3: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_votes_user_id ON votes(user_id);
CREATE INDEX IF NOT EXISTS idx_votes_post_id ON votes(post_id);
CREATE INDEX IF NOT EXISTS idx_votes_comment_id ON votes(comment_id);

-- STEP 4: Enable RLS on votes table
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- STEP 5: Create RLS policies for votes
DROP POLICY IF EXISTS "Users can view all votes" ON votes;
CREATE POLICY "Users can view all votes"
ON votes FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can insert their own votes" ON votes;
CREATE POLICY "Users can insert their own votes"
ON votes FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own votes" ON votes;
CREATE POLICY "Users can update their own votes"
ON votes FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own votes" ON votes;
CREATE POLICY "Users can delete their own votes"
ON votes FOR DELETE
USING (auth.uid() = user_id);

-- STEP 6: Create RPC functions for vote counting
-- These functions update the upvotes/downvotes counters on posts/comments

-- Increment upvotes on a post
CREATE OR REPLACE FUNCTION increment_upvotes(row_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE forum_posts
  SET upvotes = upvotes + 1
  WHERE id = row_id;
END;
$$;

-- Decrement upvotes on a post
CREATE OR REPLACE FUNCTION decrement_upvotes(row_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE forum_posts
  SET upvotes = GREATEST(upvotes - 1, 0)
  WHERE id = row_id;
END;
$$;

-- Increment downvotes on a post
CREATE OR REPLACE FUNCTION increment_downvotes(row_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE forum_posts
  SET downvotes = downvotes + 1
  WHERE id = row_id;
END;
$$;

-- Decrement downvotes on a post
CREATE OR REPLACE FUNCTION decrement_downvotes(row_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE forum_posts
  SET downvotes = GREATEST(downvotes - 1, 0)
  WHERE id = row_id;
END;
$$;

-- STEP 7: Create trigger to automatically update vote counts
-- This is more reliable than calling RPC functions

-- Function to handle vote changes
CREATE OR REPLACE FUNCTION handle_vote_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Handle post votes
  IF NEW.post_id IS NOT NULL THEN
    -- On INSERT
    IF TG_OP = 'INSERT' THEN
      IF NEW.vote_type = 'up' THEN
        UPDATE forum_posts SET upvotes = upvotes + 1 WHERE id = NEW.post_id;
      ELSE
        UPDATE forum_posts SET downvotes = downvotes + 1 WHERE id = NEW.post_id;
      END IF;
    
    -- On UPDATE (changing vote type)
    ELSIF TG_OP = 'UPDATE' AND OLD.vote_type != NEW.vote_type THEN
      IF NEW.vote_type = 'up' THEN
        UPDATE forum_posts 
        SET upvotes = upvotes + 1, downvotes = GREATEST(downvotes - 1, 0)
        WHERE id = NEW.post_id;
      ELSE
        UPDATE forum_posts 
        SET downvotes = downvotes + 1, upvotes = GREATEST(upvotes - 1, 0)
        WHERE id = NEW.post_id;
      END IF;
    
    -- On DELETE
    ELSIF TG_OP = 'DELETE' THEN
      IF OLD.vote_type = 'up' THEN
        UPDATE forum_posts SET upvotes = GREATEST(upvotes - 1, 0) WHERE id = OLD.post_id;
      ELSE
        UPDATE forum_posts SET downvotes = GREATEST(downvotes - 1, 0) WHERE id = OLD.post_id;
      END IF;
      RETURN OLD;
    END IF;
  
  -- Handle comment votes
  ELSIF NEW.comment_id IS NOT NULL OR OLD.comment_id IS NOT NULL THEN
    -- On INSERT
    IF TG_OP = 'INSERT' THEN
      IF NEW.vote_type = 'up' THEN
        UPDATE forum_comments SET upvotes = upvotes + 1 WHERE id = NEW.comment_id;
      ELSE
        UPDATE forum_comments SET downvotes = downvotes + 1 WHERE id = NEW.comment_id;
      END IF;
    
    -- On UPDATE
    ELSIF TG_OP = 'UPDATE' AND OLD.vote_type != NEW.vote_type THEN
      IF NEW.vote_type = 'up' THEN
        UPDATE forum_comments 
        SET upvotes = upvotes + 1, downvotes = GREATEST(downvotes - 1, 0)
        WHERE id = NEW.comment_id;
      ELSE
        UPDATE forum_comments 
        SET downvotes = downvotes + 1, upvotes = GREATEST(upvotes - 1, 0)
        WHERE id = NEW.comment_id;
      END IF;
    
    -- On DELETE
    ELSIF TG_OP = 'DELETE' THEN
      IF OLD.vote_type = 'up' THEN
        UPDATE forum_comments SET upvotes = GREATEST(upvotes - 1, 0) WHERE id = OLD.comment_id;
      ELSE
        UPDATE forum_comments SET downvotes = GREATEST(downvotes - 1, 0) WHERE id = OLD.comment_id;
      END IF;
      RETURN OLD;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS on_vote_change ON votes;
CREATE TRIGGER on_vote_change
  AFTER INSERT OR UPDATE OR DELETE ON votes
  FOR EACH ROW
  EXECUTE FUNCTION handle_vote_change();

-- STEP 8: Verify setup
SELECT 
  'votes' as table_name,
  EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'votes') as exists;

SELECT 
  proname as function_name,
  'RPC Function' as type
FROM pg_proc 
WHERE proname IN ('increment_upvotes', 'decrement_upvotes', 'increment_downvotes', 'decrement_downvotes', 'handle_vote_change');

-- STEP 9: Test the system (optional)
-- Uncomment to test:
/*
-- Insert a test vote (replace with actual post_id)
INSERT INTO votes (user_id, post_id, vote_type)
VALUES (auth.uid(), 'YOUR_POST_ID_HERE', 'up');

-- Check if upvotes increased
SELECT id, title, upvotes, downvotes FROM forum_posts WHERE id = 'YOUR_POST_ID_HERE';
*/

-- ============================================
-- SUCCESS! Forum voting system is now ready.
-- ============================================
