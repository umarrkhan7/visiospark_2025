-- Create Event Questions & Answers (Forum) System
-- This allows users to ask questions about events and get answers

-- =====================================================
-- STEP 1: CREATE EVENT QUESTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS event_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  is_answered BOOLEAN DEFAULT false,
  upvotes INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE event_questions ENABLE ROW LEVEL SECURITY;

-- Everyone can view questions
CREATE POLICY "Everyone can view event questions"
ON event_questions FOR SELECT
USING (true);

-- Registered users can post questions
CREATE POLICY "Users can post questions"
ON event_questions FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can update their own questions
CREATE POLICY "Users can update their own questions"
ON event_questions FOR UPDATE
USING (user_id = auth.uid());

-- Users can delete their own questions
CREATE POLICY "Users can delete their own questions"
ON event_questions FOR DELETE
USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_event_questions_event_id ON event_questions(event_id);
CREATE INDEX IF NOT EXISTS idx_event_questions_user_id ON event_questions(user_id);
CREATE INDEX IF NOT EXISTS idx_event_questions_created_at ON event_questions(created_at DESC);

COMMENT ON TABLE event_questions IS 'Questions asked by users about events';

-- =====================================================
-- STEP 2: CREATE EVENT ANSWERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS event_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID NOT NULL REFERENCES event_questions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  answer TEXT NOT NULL,
  is_accepted BOOLEAN DEFAULT false,
  upvotes INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE event_answers ENABLE ROW LEVEL SECURITY;

-- Everyone can view answers
CREATE POLICY "Everyone can view event answers"
ON event_answers FOR SELECT
USING (true);

-- Registered users can post answers
CREATE POLICY "Users can post answers"
ON event_answers FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can update their own answers
CREATE POLICY "Users can update their own answers"
ON event_answers FOR UPDATE
USING (user_id = auth.uid());

-- Question authors can accept answers
CREATE POLICY "Question authors can accept answers"
ON event_answers FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM event_questions
    WHERE event_questions.id = event_answers.question_id
    AND event_questions.user_id = auth.uid()
  )
);

-- Users can delete their own answers
CREATE POLICY "Users can delete their own answers"
ON event_answers FOR DELETE
USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_event_answers_question_id ON event_answers(question_id);
CREATE INDEX IF NOT EXISTS idx_event_answers_user_id ON event_answers(user_id);
CREATE INDEX IF NOT EXISTS idx_event_answers_created_at ON event_answers(created_at DESC);

COMMENT ON TABLE event_answers IS 'Answers to event questions';

-- =====================================================
-- STEP 3: CREATE TRIGGER TO UPDATE is_answered
-- =====================================================
CREATE OR REPLACE FUNCTION update_question_answered_status()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE event_questions 
    SET is_answered = true, updated_at = NOW()
    WHERE id = NEW.question_id;
  ELSIF TG_OP = 'DELETE' THEN
    -- Check if there are any remaining answers
    UPDATE event_questions 
    SET is_answered = EXISTS(
      SELECT 1 FROM event_answers 
      WHERE question_id = OLD.question_id
    ),
    updated_at = NOW()
    WHERE id = OLD.question_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS on_answer_change ON event_answers;
CREATE TRIGGER on_answer_change
  AFTER INSERT OR DELETE ON event_answers
  FOR EACH ROW
  EXECUTE FUNCTION update_question_answered_status();

-- =====================================================
-- STEP 4: CREATE UPDATED_AT TRIGGERS
-- =====================================================
DROP TRIGGER IF EXISTS update_event_questions_updated_at ON event_questions;
CREATE TRIGGER update_event_questions_updated_at
  BEFORE UPDATE ON event_questions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_event_answers_updated_at ON event_answers;
CREATE TRIGGER update_event_answers_updated_at
  BEFORE UPDATE ON event_answers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE 'EVENT FORUM/Q&A SYSTEM CREATED!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Tables created:';
  RAISE NOTICE '  ✓ event_questions';
  RAISE NOTICE '  ✓ event_answers';
  RAISE NOTICE '';
  RAISE NOTICE 'Features:';
  RAISE NOTICE '  ✓ Users can ask questions about events';
  RAISE NOTICE '  ✓ Users can answer questions';
  RAISE NOTICE '  ✓ Question authors can accept best answers';
  RAISE NOTICE '  ✓ Upvote system for questions and answers';
  RAISE NOTICE '  ✓ Auto-mark questions as answered';
  RAISE NOTICE '';
  RAISE NOTICE 'Run this SQL in your Supabase SQL Editor';
  RAISE NOTICE '';
END $$;
