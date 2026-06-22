-- Create event_ratings table to store student ratings for events
CREATE TABLE IF NOT EXISTS public.event_ratings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Ensure a student can only rate an event once (upsert will overwrite/update)
    CONSTRAINT unique_student_event_rating UNIQUE (event_id, student_name)
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.event_ratings ENABLE ROW LEVEL SECURITY;

-- Create policies for event_ratings
CREATE POLICY "Allow read for all users" ON public.event_ratings
    FOR SELECT USING (true);

CREATE POLICY "Allow insert/update/delete for all users" ON public.event_ratings
    FOR ALL USING (true) WITH CHECK (true);

-- Create a view for administrators to see event ratings statistics
CREATE OR REPLACE VIEW public.admin_event_ratings AS
SELECT 
    e.id AS event_id,
    e."eventName" AS event_name,
    ROUND(COALESCE(AVG(r.rating), 0)::numeric, 2) AS average_rating,
    COUNT(r.id) AS total_ratings
FROM public.events e
LEFT JOIN public.event_ratings r ON e.id = r.event_id
GROUP BY e.id, e."eventName";
