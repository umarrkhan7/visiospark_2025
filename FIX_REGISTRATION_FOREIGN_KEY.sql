-- Fix Foreign Key Relationships for event_registrations table
-- This script adds the missing foreign key constraint between event_registrations and profiles
-- Run this in your Supabase SQL Editor

-- First, check if the foreign key already exists
DO $$ 
BEGIN
    -- Add foreign key constraint for user_id -> profiles(id)
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'event_registrations_user_id_fkey'
    ) THEN
        ALTER TABLE event_registrations
        ADD CONSTRAINT event_registrations_user_id_fkey 
        FOREIGN KEY (user_id) 
        REFERENCES profiles(id) 
        ON DELETE CASCADE;
        
        RAISE NOTICE 'Foreign key constraint added successfully';
    ELSE
        RAISE NOTICE 'Foreign key constraint already exists';
    END IF;
END $$;

-- Verify the constraint was added
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'event_registrations'
    AND tc.constraint_type = 'FOREIGN KEY';
