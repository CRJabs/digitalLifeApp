-- Create student_fines table to store outstanding dues and notices for students
CREATE TABLE IF NOT EXISTS public.student_fines (
    student_name TEXT PRIMARY KEY,
    outstanding_dues NUMERIC(10, 2) DEFAULT 0.00 NOT NULL,
    notices TEXT DEFAULT '' NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.student_fines ENABLE ROW LEVEL SECURITY;

-- Create policies for student_fines
CREATE POLICY "Allow read for authenticated users" ON public.student_fines
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert/update/delete for authenticated users" ON public.student_fines
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Create carousel_items table to store admin announcements
CREATE TABLE IF NOT EXISTS public.carousel_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.carousel_items ENABLE ROW LEVEL SECURITY;

-- Create policies for carousel_items
CREATE POLICY "Allow read for authenticated users" ON public.carousel_items
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert/update/delete for authenticated users" ON public.carousel_items
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
