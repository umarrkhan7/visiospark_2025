-- =====================================================
-- UNIWEEK DATABASE SCHEMA - COMPLETE SETUP
-- Student Week Event Management System
-- =====================================================
-- Purpose: Create all tables, policies, and functions for UniWeek
-- Date: November 29, 2025
-- =====================================================

-- =====================================================
-- STEP 1: CREATE SOCIETIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS societies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  short_name TEXT NOT NULL UNIQUE, -- ACM, CLS, CSS
  description TEXT,
  color TEXT NOT NULL, -- Hex color for UI
  icon TEXT, -- Icon name or emoji
  logo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE societies ENABLE ROW LEVEL SECURITY;

-- Everyone can view societies
CREATE POLICY "Everyone can view societies"
ON societies FOR SELECT
USING (true);

-- Only admins can modify (for now, we'll allow all authenticated users)
CREATE POLICY "Authenticated users can manage societies"
ON societies FOR ALL
USING (auth.role() = 'authenticated');

COMMENT ON TABLE societies IS 'Student societies: ACM (Technical), CLS (Literature), CSS (Sports)';

-- =====================================================
-- STEP 2: EXTEND PROFILES TABLE WITH ROLE
-- =====================================================
-- Add role and society_id columns to existing profiles table
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'student' CHECK (role IN ('student', 'society_handler')),
  ADD COLUMN IF NOT EXISTS society_id UUID REFERENCES societies(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS interests TEXT[], -- Array of interest tags for students
  ADD COLUMN IF NOT EXISTS participation_count INTEGER DEFAULT 0; -- For leaderboard

COMMENT ON COLUMN profiles.role IS 'User role: student or society_handler';
COMMENT ON COLUMN profiles.society_id IS 'Society ID for handlers (ACM/CLS/CSS), null for students';
COMMENT ON COLUMN profiles.interests IS 'Student interests for AI recommendations';
COMMENT ON COLUMN profiles.participation_count IS 'Number of events attended';

-- Create index for role queries
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_society_id ON profiles(society_id);

-- =====================================================
-- STEP 3: CREATE EVENT CATEGORIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS event_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  society_id UUID REFERENCES societies(id) ON DELETE CASCADE,
  icon TEXT,
  color TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE event_categories ENABLE ROW LEVEL SECURITY;

-- Everyone can view categories
CREATE POLICY "Everyone can view event categories"
ON event_categories FOR SELECT
USING (true);

COMMENT ON TABLE event_categories IS 'Event categories: technical, literary, sports activities';

-- =====================================================
-- STEP 4: CREATE EVENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  category_id UUID REFERENCES event_categories(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  event_type TEXT NOT NULL, -- technical, literary, sports
  date_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE,
  venue TEXT NOT NULL,
  capacity INTEGER NOT NULL CHECK (capacity > 0),
  registered_count INTEGER DEFAULT 0 CHECK (registered_count >= 0),
  status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
  image_url TEXT,
  tags TEXT[], -- For filtering and search
  registration_deadline TIMESTAMP WITH TIME ZONE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Everyone can view events
CREATE POLICY "Everyone can view events"
ON events FOR SELECT
USING (true);

-- Only society handlers can create events for their society
CREATE POLICY "Society handlers can create events"
ON events FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'society_handler'
    AND profiles.society_id = events.society_id
  )
);

-- Only society handlers can update their own events
CREATE POLICY "Society handlers can update their events"
ON events FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'society_handler'
    AND profiles.society_id = events.society_id
  )
);

-- Only society handlers can delete their own events
CREATE POLICY "Society handlers can delete their events"
ON events FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'society_handler'
    AND profiles.society_id = events.society_id
  )
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_events_society_id ON events(society_id);
CREATE INDEX IF NOT EXISTS idx_events_date_time ON events(date_time);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events(created_by);

COMMENT ON TABLE events IS 'All events organized by ACM, CLS, and CSS';

-- =====================================================
-- STEP 5: CREATE EVENT REGISTRATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS event_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'registered' CHECK (status IN ('registered', 'attended', 'cancelled')),
  registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  attended_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(event_id, user_id) -- Prevent duplicate registrations
);

-- Enable RLS
ALTER TABLE event_registrations ENABLE ROW LEVEL SECURITY;

-- Users can view their own registrations
CREATE POLICY "Users can view their own registrations"
ON event_registrations FOR SELECT
USING (user_id = auth.uid());

-- Society handlers can view registrations for their events
CREATE POLICY "Society handlers can view event registrations"
ON event_registrations FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM events e
    JOIN profiles p ON p.society_id = e.society_id
    WHERE e.id = event_registrations.event_id
    AND p.id = auth.uid()
    AND p.role = 'society_handler'
  )
);

-- Users can register for events
CREATE POLICY "Users can register for events"
ON event_registrations FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can cancel their own registrations
CREATE POLICY "Users can update their own registrations"
ON event_registrations FOR UPDATE
USING (user_id = auth.uid());

-- Society handlers can mark attendance
CREATE POLICY "Society handlers can mark attendance"
ON event_registrations FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM events e
    JOIN profiles p ON p.society_id = e.society_id
    WHERE e.id = event_registrations.event_id
    AND p.id = auth.uid()
    AND p.role = 'society_handler'
  )
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_event_registrations_event_id ON event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_user_id ON event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_status ON event_registrations(status);

COMMENT ON TABLE event_registrations IS 'Student registrations for events';

-- =====================================================
-- STEP 6: CREATE EVENT FEEDBACK TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS event_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  is_anonymous BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id) -- One feedback per user per event
);

-- Enable RLS
ALTER TABLE event_feedback ENABLE ROW LEVEL SECURITY;

-- Everyone can view feedback (respect anonymity in app)
CREATE POLICY "Everyone can view event feedback"
ON event_feedback FOR SELECT
USING (true);

-- Users can submit feedback for events they attended
CREATE POLICY "Users can submit feedback"
ON event_feedback FOR INSERT
WITH CHECK (
  user_id = auth.uid() AND
  EXISTS (
    SELECT 1 FROM event_registrations
    WHERE event_registrations.event_id = event_feedback.event_id
    AND event_registrations.user_id = auth.uid()
  )
);

-- Users can update their own feedback
CREATE POLICY "Users can update their own feedback"
ON event_feedback FOR UPDATE
USING (user_id = auth.uid());

-- Users can delete their own feedback
CREATE POLICY "Users can delete their own feedback"
ON event_feedback FOR DELETE
USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_event_feedback_event_id ON event_feedback(event_id);
CREATE INDEX IF NOT EXISTS idx_event_feedback_user_id ON event_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_event_feedback_rating ON event_feedback(rating);

COMMENT ON TABLE event_feedback IS 'Student feedback and ratings for completed events';

-- =====================================================
-- STEP 7: CREATE EVENT REMINDERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS event_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reminder_time TIMESTAMP WITH TIME ZONE NOT NULL,
  is_sent BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id) -- One reminder per user per event
);

-- Enable RLS
ALTER TABLE event_reminders ENABLE ROW LEVEL SECURITY;

-- Users can view their own reminders
CREATE POLICY "Users can view their own reminders"
ON event_reminders FOR SELECT
USING (user_id = auth.uid());

-- Users can create their own reminders
CREATE POLICY "Users can create reminders"
ON event_reminders FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can update their own reminders
CREATE POLICY "Users can update their own reminders"
ON event_reminders FOR UPDATE
USING (user_id = auth.uid());

-- Users can delete their own reminders
CREATE POLICY "Users can delete their own reminders"
ON event_reminders FOR DELETE
USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_event_reminders_user_id ON event_reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_event_reminders_reminder_time ON event_reminders(reminder_time);
CREATE INDEX IF NOT EXISTS idx_event_reminders_is_sent ON event_reminders(is_sent) WHERE is_sent = false;

COMMENT ON TABLE event_reminders IS 'Calendar reminders for registered events';

-- =====================================================
-- STEP 8: CREATE ACHIEVEMENTS TABLE (OPTIONAL - LEADERBOARD)
-- =====================================================
CREATE TABLE IF NOT EXISTS achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  icon TEXT,
  badge_url TEXT,
  requirement_type TEXT NOT NULL, -- events_attended, society_participation, etc.
  requirement_count INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

-- Everyone can view achievements
CREATE POLICY "Everyone can view achievements"
ON achievements FOR SELECT
USING (true);

COMMENT ON TABLE achievements IS 'Badges and achievements for student participation';

-- =====================================================
-- STEP 9: CREATE USER ACHIEVEMENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
  earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

-- Enable RLS
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- Users can view their own achievements
CREATE POLICY "Users can view their own achievements"
ON user_achievements FOR SELECT
USING (user_id = auth.uid());

-- Everyone can view all achievements (for leaderboard)
CREATE POLICY "Everyone can view all user achievements"
ON user_achievements FOR SELECT
USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON user_achievements(achievement_id);

COMMENT ON TABLE user_achievements IS 'Achievements earned by users';

-- =====================================================
-- STEP 10: CREATE TEAMS TABLE (OPTIONAL)
-- =====================================================
CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  leader_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  max_members INTEGER DEFAULT 5,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'full', 'closed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

-- Everyone can view teams
CREATE POLICY "Everyone can view teams"
ON teams FOR SELECT
USING (true);

-- Users can create teams
CREATE POLICY "Users can create teams"
ON teams FOR INSERT
WITH CHECK (leader_id = auth.uid());

-- Team leaders can update their teams
CREATE POLICY "Team leaders can update teams"
ON teams FOR UPDATE
USING (leader_id = auth.uid());

-- Team leaders can delete their teams
CREATE POLICY "Team leaders can delete teams"
ON teams FOR DELETE
USING (leader_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_teams_event_id ON teams(event_id);
CREATE INDEX IF NOT EXISTS idx_teams_leader_id ON teams(leader_id);

COMMENT ON TABLE teams IS 'Teams for coding competitions and sports events';

-- =====================================================
-- STEP 11: CREATE TEAM MEMBERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'joined' CHECK (status IN ('joined', 'invited', 'left')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(team_id, user_id)
);

-- Enable RLS
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;

-- Everyone can view team members
CREATE POLICY "Everyone can view team members"
ON team_members FOR SELECT
USING (true);

-- Users can join teams
CREATE POLICY "Users can join teams"
ON team_members FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can leave teams
CREATE POLICY "Users can update their team membership"
ON team_members FOR UPDATE
USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_team_members_team_id ON team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user_id ON team_members(user_id);

COMMENT ON TABLE team_members IS 'Members of event teams';

-- =====================================================
-- STEP 12: CREATE EVENT WAITLIST TABLE (OPTIONAL)
-- =====================================================
CREATE TABLE IF NOT EXISTS event_waitlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  notified BOOLEAN DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- Enable RLS
ALTER TABLE event_waitlist ENABLE ROW LEVEL SECURITY;

-- Users can view their own waitlist entries
CREATE POLICY "Users can view their own waitlist entries"
ON event_waitlist FOR SELECT
USING (user_id = auth.uid());

-- Society handlers can view waitlist for their events
CREATE POLICY "Society handlers can view event waitlist"
ON event_waitlist FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM events e
    JOIN profiles p ON p.society_id = e.society_id
    WHERE e.id = event_waitlist.event_id
    AND p.id = auth.uid()
    AND p.role = 'society_handler'
  )
);

-- Users can join waitlist
CREATE POLICY "Users can join waitlist"
ON event_waitlist FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can leave waitlist
CREATE POLICY "Users can leave waitlist"
ON event_waitlist FOR DELETE
USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_event_waitlist_event_id ON event_waitlist(event_id);
CREATE INDEX IF NOT EXISTS idx_event_waitlist_user_id ON event_waitlist(user_id);

COMMENT ON TABLE event_waitlist IS 'Waitlist for full capacity events';

-- =====================================================
-- STEP 13: CREATE FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update registered_count when registration changes
CREATE OR REPLACE FUNCTION update_event_registered_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'registered' THEN
    UPDATE events SET registered_count = registered_count + 1 WHERE id = NEW.event_id;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'registered' AND NEW.status != 'registered' THEN
      UPDATE events SET registered_count = GREATEST(registered_count - 1, 0) WHERE id = NEW.event_id;
    ELSIF OLD.status != 'registered' AND NEW.status = 'registered' THEN
      UPDATE events SET registered_count = registered_count + 1 WHERE id = NEW.event_id;
    END IF;
  ELSIF TG_OP = 'DELETE' AND OLD.status = 'registered' THEN
    UPDATE events SET registered_count = GREATEST(registered_count - 1, 0) WHERE id = OLD.event_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS on_registration_change ON event_registrations;
CREATE TRIGGER on_registration_change
  AFTER INSERT OR UPDATE OR DELETE ON event_registrations
  FOR EACH ROW
  EXECUTE FUNCTION update_event_registered_count();

-- Function to update participation count
CREATE OR REPLACE FUNCTION update_participation_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status != 'attended' AND NEW.status = 'attended' THEN
    UPDATE profiles SET participation_count = participation_count + 1 WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS on_attendance_marked ON event_registrations;
CREATE TRIGGER on_attendance_marked
  AFTER UPDATE ON event_registrations
  FOR EACH ROW
  EXECUTE FUNCTION update_participation_count();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_societies_updated_at ON societies;
CREATE TRIGGER update_societies_updated_at
  BEFORE UPDATE ON societies
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_events_updated_at ON events;
CREATE TRIGGER update_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_teams_updated_at ON teams;
CREATE TRIGGER update_teams_updated_at
  BEFORE UPDATE ON teams
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- STEP 14: SEED INITIAL DATA
-- =====================================================

-- Insert 3 societies
INSERT INTO societies (name, short_name, description, color, icon) VALUES
  (
    'Association for Computing Machinery',
    'ACM',
    'Technical society organizing coding competitions, workshops, and tech seminars',
    '#6366F1',
    'code'
  ),
  (
    'Cultural & Literary Society',
    'CLS',
    'Literature and pop culture society for debates, essays, and entertainment',
    '#EC4899',
    'book'
  ),
  (
    'Computer Science Sports',
    'CSS',
    'Sports society managing football, cricket, and athletic tournaments',
    '#10B981',
    'sports_soccer'
  )
ON CONFLICT (short_name) DO NOTHING;

-- Insert event categories
INSERT INTO event_categories (name, society_id, icon, color)
SELECT 'Coding Competition', id, 'code', '#6366F1' FROM societies WHERE short_name = 'ACM'
UNION ALL
SELECT 'Workshop', id, 'school', '#818CF8' FROM societies WHERE short_name = 'ACM'
UNION ALL
SELECT 'Seminar', id, 'chat', '#4F46E5' FROM societies WHERE short_name = 'ACM'
UNION ALL
SELECT 'Debate', id, 'forum', '#EC4899' FROM societies WHERE short_name = 'CLS'
UNION ALL
SELECT 'Essay Competition', id, 'edit', '#F472B6' FROM societies WHERE short_name = 'CLS'
UNION ALL
SELECT 'Watch Party', id, 'movie', '#FCA5A5' FROM societies WHERE short_name = 'CLS'
UNION ALL
SELECT 'Football', id, 'sports_soccer', '#10B981' FROM societies WHERE short_name = 'CSS'
UNION ALL
SELECT 'Cricket', id, 'sports_cricket', '#34D399' FROM societies WHERE short_name = 'CSS'
UNION ALL
SELECT 'Athletics', id, 'directions_run', '#059669' FROM societies WHERE short_name = 'CSS'
ON CONFLICT DO NOTHING;

-- Insert sample achievements
INSERT INTO achievements (name, description, icon, requirement_type, requirement_count) VALUES
  ('First Timer', 'Attended your first event', '🎉', 'events_attended', 1),
  ('Regular', 'Attended 5 events', '⭐', 'events_attended', 5),
  ('Super Active', 'Attended 10 events', '🏆', 'events_attended', 10),
  ('Tech Enthusiast', 'Attended 5 ACM events', '💻', 'society_participation', 5),
  ('Literary Champion', 'Attended 5 CLS events', '📚', 'society_participation', 5),
  ('Sports Star', 'Attended 5 CSS events', '⚽', 'society_participation', 5)
ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- STEP 15: VERIFICATION
-- =====================================================

-- Verify tables created
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE 'UNIWEEK DATABASE SETUP COMPLETED!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Tables created:';
  RAISE NOTICE '  ✓ societies (3 societies seeded)';
  RAISE NOTICE '  ✓ event_categories (9 categories seeded)';
  RAISE NOTICE '  ✓ events';
  RAISE NOTICE '  ✓ event_registrations';
  RAISE NOTICE '  ✓ event_feedback';
  RAISE NOTICE '  ✓ event_reminders';
  RAISE NOTICE '  ✓ achievements (6 achievements seeded)';
  RAISE NOTICE '  ✓ user_achievements';
  RAISE NOTICE '  ✓ teams';
  RAISE NOTICE '  ✓ team_members';
  RAISE NOTICE '  ✓ event_waitlist';
  RAISE NOTICE '';
  RAISE NOTICE 'Profiles table extended with:';
  RAISE NOTICE '  ✓ role (student/society_handler)';
  RAISE NOTICE '  ✓ society_id';
  RAISE NOTICE '  ✓ interests';
  RAISE NOTICE '  ✓ participation_count';
  RAISE NOTICE '';
  RAISE NOTICE 'RLS Policies: Enabled and configured';
  RAISE NOTICE 'Triggers: Auto-update counters active';
  RAISE NOTICE '';
  RAISE NOTICE 'Next step: Run this SQL in Supabase SQL Editor';
  RAISE NOTICE '';
END $$;
