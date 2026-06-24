-- ================================================================
-- Digital LiFe App — Performance Optimization Indexes
-- 
-- Run this in the Supabase SQL Editor.
-- ================================================================

-- 1. Index attendees table for email and event queries
CREATE INDEX IF NOT EXISTS idx_attendees_student_email 
    ON public.attendees(student_email);
CREATE INDEX IF NOT EXISTS idx_attendees_event_id 
    ON public.attendees("eventId");

-- 2. Index event_ratings table for ratings fetches
CREATE INDEX IF NOT EXISTS idx_event_ratings_student_name 
    ON public.event_ratings(student_name);
CREATE INDEX IF NOT EXISTS idx_event_ratings_event_id 
    ON public.event_ratings(event_id);
