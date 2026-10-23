-- Migration: 20261023000000_permanent_optimization.sql
-- Description: Permanent architectural optimization for student fines and QR scanning.
-- Note: 'service_rendered' table calculations are temporarily disabled per user instruction.

-- 1. Create student_fines_summary physical table
CREATE TABLE IF NOT EXISTS public.student_fines_summary (
    student_uid TEXT PRIMARY KEY,
    student_email TEXT NOT NULL UNIQUE,
    student_name TEXT NOT NULL,
    accumulated_dues NUMERIC DEFAULT 0,
    hours_rendered NUMERIC DEFAULT 0,
    outstanding_dues NUMERIC GENERATED ALWAYS AS (
        GREATEST(accumulated_dues - (hours_rendered * 50), 0)
    ) STORED,
    total_points INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT now()
);

-- Indexes on student_fines_summary for ultra-fast ordering and filtering
CREATE INDEX IF NOT EXISTS idx_fines_summary_name ON public.student_fines_summary (student_name);
CREATE INDEX IF NOT EXISTS idx_fines_summary_dues ON public.student_fines_summary (outstanding_dues DESC);
CREATE INDEX IF NOT EXISTS idx_fines_summary_email ON public.student_fines_summary (lower(student_email));

-- Enable RLS and grant read/write access
ALTER TABLE public.student_fines_summary ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read student_fines_summary" ON public.student_fines_summary;
DROP POLICY IF EXISTS "Allow write student_fines_summary" ON public.student_fines_summary;
CREATE POLICY "Allow write student_fines_summary" ON public.student_fines_summary 
    FOR ALL TO public USING (true) WITH CHECK (true);

GRANT ALL ON public.student_fines_summary TO anon, authenticated, service_role;

-- 2. Performance Indexes on existing tables to eliminate seq scans
CREATE INDEX IF NOT EXISTS idx_users_name ON public.users (name);
CREATE INDEX IF NOT EXISTS idx_users_lower_email ON public.users (lower(email));
CREATE INDEX IF NOT EXISTS idx_attendees_event_lower_email ON public.attendees ("eventId", lower(student_email));
CREATE INDEX IF NOT EXISTS idx_attendees_event_lower_email_col ON public.attendees ("eventId", lower(email));
CREATE INDEX IF NOT EXISTS idx_event_ratings_event_lower_email ON public.event_ratings (event_id, lower(student_email));
CREATE INDEX IF NOT EXISTS idx_event_ratings_event_lower_name ON public.event_ratings (event_id, lower(student_name));

-- Drop duplicate index on attendees(student_email) if exists
DROP INDEX IF EXISTS public.idx_attendees_email;

-- 3. Stored function: recalculate_student_fines (single student)
-- Note: service_rendered is temporarily disabled (hours_rendered defaulted to 0)
CREATE OR REPLACE FUNCTION public.recalculate_student_fines(target_student_email TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid TEXT;
    v_name TEXT;
    v_dues NUMERIC := 0;
    v_points INTEGER := 0;
BEGIN
    IF target_student_email IS NULL THEN RETURN; END IF;

    -- Fetch user identity
    SELECT uid, name INTO v_uid, v_name 
      FROM public.users 
     WHERE lower(email) = lower(target_student_email) 
     LIMIT 1;

    IF v_uid IS NULL THEN RETURN; END IF;

    -- Calculate accumulated dues and total points for compulsory events
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN e.duration = 'morning' THEN
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningOut", false) THEN 0 ELSE 50 END)
                WHEN e.duration = 'afternoon' THEN
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonOut", false) THEN 0 ELSE 50 END)
                WHEN e.duration = 'whole day' THEN
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningOut", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonOut", false) THEN 0 ELSE 50 END)
                ELSE 0
            END
        ), 0),
        COALESCE(SUM(
            CASE 
                WHEN e."providePoints" = true AND r.id IS NOT NULL AND (
                    (e.duration = 'morning' AND COALESCE(a."morningIn", false) AND COALESCE(a."morningOut", false)) OR
                    (e.duration = 'afternoon' AND COALESCE(a."afternoonIn", false) AND COALESCE(a."afternoonOut", false)) OR
                    (e.duration = 'whole day' AND COALESCE(a."morningIn", false) AND COALESCE(a."morningOut", false) AND COALESCE(a."afternoonIn", false) AND COALESCE(a."afternoonOut", false))
                ) THEN COALESCE(e."pointsAwarded", 0)
                ELSE 0
            END
        ), 0)
    INTO v_dues, v_points
    FROM public.events e
    LEFT JOIN public.attendees a 
           ON a."eventId" = e.id AND (lower(a.student_email) = lower(target_student_email) OR lower(a.email) = lower(target_student_email))
    LEFT JOIN public.event_ratings r 
           ON r.event_id = e.id AND (lower(r.student_email) = lower(target_student_email) OR lower(r.student_name) = lower(v_name))
    WHERE e."isCompulsory" = true OR e."isCompulsory" IS NULL;

    -- Upsert into summary table (hours_rendered is 0 while service_rendered is disabled)
    INSERT INTO public.student_fines_summary (
        student_uid, student_email, student_name, accumulated_dues, hours_rendered, total_points, last_updated
    ) VALUES (
        v_uid, lower(target_student_email), v_name, v_dues, 0, v_points, now()
    )
    ON CONFLICT (student_uid) DO UPDATE SET
        student_name = EXCLUDED.student_name,
        student_email = EXCLUDED.student_email,
        accumulated_dues = EXCLUDED.accumulated_dues,
        hours_rendered = 0,
        total_points = EXCLUDED.total_points,
        last_updated = now();
END;
$$;

-- 4. Stored function: recalculate_all_student_fines (bulk population)
CREATE OR REPLACE FUNCTION public.recalculate_all_student_fines()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.student_fines_summary (
        student_uid, student_email, student_name, accumulated_dues, hours_rendered, total_points, last_updated
    )
    SELECT 
        u.uid AS student_uid,
        lower(u.email) AS student_email,
        u.name AS student_name,
        COALESCE(SUM(
            CASE 
                WHEN e.duration = 'morning' THEN
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningOut", false) THEN 0 ELSE 50 END)
                WHEN e.duration = 'afternoon' THEN
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonOut", false) THEN 0 ELSE 50 END)
                WHEN e.duration = 'whole day' THEN
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningOut", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonIn", false) THEN 0 ELSE 50 END) +
                    (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonOut", false) THEN 0 ELSE 50 END)
                ELSE 0
            END
        ), 0) AS accumulated_dues,
        0 AS hours_rendered,
        COALESCE(SUM(
            CASE 
                WHEN e."providePoints" = true AND r.id IS NOT NULL AND (
                    (e.duration = 'morning' AND COALESCE(a."morningIn", false) AND COALESCE(a."morningOut", false)) OR
                    (e.duration = 'afternoon' AND COALESCE(a."afternoonIn", false) AND COALESCE(a."afternoonOut", false)) OR
                    (e.duration = 'whole day' AND COALESCE(a."morningIn", false) AND COALESCE(a."morningOut", false) AND COALESCE(a."afternoonIn", false) AND COALESCE(a."afternoonOut", false))
                ) THEN COALESCE(e."pointsAwarded", 0)
                ELSE 0
            END
        ), 0) AS total_points,
        now() AS last_updated
    FROM public.users u
    CROSS JOIN public.events e
    LEFT JOIN public.attendees a 
           ON a."eventId" = e.id AND (lower(a.student_email) = lower(u.email) OR lower(a.email) = lower(u.email))
    LEFT JOIN public.event_ratings r 
           ON r.event_id = e.id AND (lower(r.student_email) = lower(u.email) OR lower(r.student_name) = lower(u.name))
    WHERE (e."isCompulsory" = true OR e."isCompulsory" IS NULL)
    GROUP BY u.uid, lower(u.email), u.name
    ON CONFLICT (student_uid) DO UPDATE SET
        student_name = EXCLUDED.student_name,
        student_email = EXCLUDED.student_email,
        accumulated_dues = EXCLUDED.accumulated_dues,
        hours_rendered = EXCLUDED.hours_rendered,
        total_points = EXCLUDED.total_points,
        last_updated = now();
END;
$$;

-- Run initial population
SELECT public.recalculate_all_student_fines();

-- 5. Replace student_fines_view with lightning-fast query against summary table
CREATE OR REPLACE VIEW public.student_fines_view AS
SELECT 
    student_email,
    student_name,
    outstanding_dues,
    total_points,
    hours_rendered
FROM public.student_fines_summary;

GRANT SELECT ON public.student_fines_view TO anon, authenticated, service_role;

-- 6. Realtime Triggers to keep summary table synchronized
-- Trigger on attendees
CREATE OR REPLACE FUNCTION public.trg_fines_on_attendee_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        PERFORM public.recalculate_student_fines(COALESCE(OLD.student_email, OLD.email));
    ELSE
        PERFORM public.recalculate_student_fines(COALESCE(NEW.student_email, NEW.email));
        IF (TG_OP = 'UPDATE' AND COALESCE(OLD.student_email, OLD.email) <> COALESCE(NEW.student_email, NEW.email)) THEN
            PERFORM public.recalculate_student_fines(COALESCE(OLD.student_email, OLD.email));
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_attendees_update_fines ON public.attendees;
CREATE TRIGGER trg_attendees_update_fines
AFTER INSERT OR UPDATE OR DELETE ON public.attendees
FOR EACH ROW
EXECUTE FUNCTION public.trg_fines_on_attendee_change();

-- Trigger on event_ratings
CREATE OR REPLACE FUNCTION public.trg_fines_on_rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        IF OLD.student_email IS NOT NULL THEN
            PERFORM public.recalculate_student_fines(OLD.student_email);
        END IF;
    ELSE
        IF NEW.student_email IS NOT NULL THEN
            PERFORM public.recalculate_student_fines(NEW.student_email);
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_ratings_update_fines ON public.event_ratings;
CREATE TRIGGER trg_ratings_update_fines
AFTER INSERT OR UPDATE OR DELETE ON public.event_ratings
FOR EACH ROW
EXECUTE FUNCTION public.trg_fines_on_rating_change();

-- Trigger on users (new registration)
CREATE OR REPLACE FUNCTION public.trg_fines_on_user_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM public.recalculate_student_fines(NEW.email);
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_insert_fines ON public.users;
CREATE TRIGGER trg_users_insert_fines
AFTER INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.trg_fines_on_user_insert();

-- Trigger on events (statement-level)
CREATE OR REPLACE FUNCTION public.trg_fines_on_event_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM public.recalculate_all_student_fines();
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_events_update_fines ON public.events;
CREATE TRIGGER trg_events_update_fines
AFTER INSERT OR UPDATE OR DELETE ON public.events
FOR EACH STATEMENT
EXECUTE FUNCTION public.trg_fines_on_event_change();

-- 7. Atomic QR Scan RPC function
CREATE OR REPLACE FUNCTION public.record_attendance_scan(
    p_event_id UUID,
    p_scanned_email TEXT,
    p_scanned_name TEXT,
    p_phone TEXT,
    p_dept TEXT,
    p_program TEXT,
    p_year TEXT,
    p_field_to_set TEXT,        -- 'morningIn', 'morningOut', 'afternoonIn', 'afternoonOut'
    p_scanner_email TEXT,
    p_is_admin_scan BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_event RECORD;
    v_attendee RECORD;
    v_time_field TEXT := p_field_to_set || 'Time';
    v_manual_field TEXT := p_field_to_set || 'Manual';
    v_by_field TEXT := p_field_to_set || 'By';
    v_points_to_award INTEGER := 0;
    v_boxes_count INTEGER := 0;
    v_result JSONB;
BEGIN
    -- 1. Validate event existence
    SELECT id, "providePoints", "pointsAwarded" 
      INTO v_event 
      FROM public.events 
     WHERE id = p_event_id;

    IF v_event.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'status', 'error', 'error', 'Event not found');
    END IF;

    -- 2. Validate field name for security
    IF p_field_to_set NOT IN ('morningIn', 'morningOut', 'afternoonIn', 'afternoonOut') THEN
        RETURN jsonb_build_object('success', false, 'status', 'error', 'error', 'Invalid field_to_set');
    END IF;

    -- 3. Lock attendee row if exists to prevent race conditions
    SELECT * INTO v_attendee
      FROM public.attendees
     WHERE "eventId" = p_event_id 
       AND (lower(student_email) = lower(p_scanned_email) OR lower(email) = lower(p_scanned_email))
     FOR UPDATE;

    -- 4. Check for duplicate scan
    IF v_attendee.id IS NOT NULL THEN
        IF (p_field_to_set = 'morningIn' AND COALESCE(v_attendee."morningIn", false) = true) OR
           (p_field_to_set = 'morningOut' AND COALESCE(v_attendee."morningOut", false) = true) OR
           (p_field_to_set = 'afternoonIn' AND COALESCE(v_attendee."afternoonIn", false) = true) OR
           (p_field_to_set = 'afternoonOut' AND COALESCE(v_attendee."afternoonOut", false) = true) THEN
            RETURN jsonb_build_object('success', false, 'status', 'duplicate', 'name', v_attendee.name);
        END IF;

        -- Calculate points based on total boxes checked
        v_boxes_count := 
            (CASE WHEN COALESCE(v_attendee."morningIn", false) OR p_field_to_set = 'morningIn' THEN 1 ELSE 0 END) +
            (CASE WHEN COALESCE(v_attendee."morningOut", false) OR p_field_to_set = 'morningOut' THEN 1 ELSE 0 END) +
            (CASE WHEN COALESCE(v_attendee."afternoonIn", false) OR p_field_to_set = 'afternoonIn' THEN 1 ELSE 0 END) +
            (CASE WHEN COALESCE(v_attendee."afternoonOut", false) OR p_field_to_set = 'afternoonOut' THEN 1 ELSE 0 END);

        IF COALESCE(v_event."providePoints", false) THEN
            v_points_to_award := COALESCE(v_event."pointsAwarded", 0) * v_boxes_count;
        ELSE
            v_points_to_award := 0;
        END IF;

        -- Update existing attendee record
        EXECUTE format(
            'UPDATE public.attendees SET 
                %I = true, 
                %I = now(), 
                %I = $1, 
                %I = $2,
                scanned_by_accounts = CASE 
                    WHEN $2 IS NOT NULL AND NOT ($2 = ANY(COALESCE(scanned_by_accounts, ARRAY[]::text[]))) 
                    THEN array_append(COALESCE(scanned_by_accounts, ARRAY[]::text[]), $2)
                    ELSE COALESCE(scanned_by_accounts, ARRAY[]::text[])
                END,
                "pointsEarned" = $3
             WHERE id = $4 RETURNING to_jsonb(attendees.*)',
            p_field_to_set, v_time_field, v_manual_field, v_by_field
        ) USING p_is_admin_scan, lower(p_scanner_email), v_points_to_award, v_attendee.id INTO v_result;

        RETURN jsonb_build_object('success', true, 'status', 'updated', 'attendee', v_result);
    ELSE
        -- Insert new attendee atomically
        IF COALESCE(v_event."providePoints", false) THEN
            v_points_to_award := COALESCE(v_event."pointsAwarded", 0);
        ELSE
            v_points_to_award := 0;
        END IF;

        EXECUTE format(
            'INSERT INTO public.attendees (
                name, email, student_email, "phoneNumber", department, program, "yearLevel", "eventId",
                %I, %I, %I, %I, scanned_by_accounts, "pointsEarned"
            ) VALUES (
                $1, $2, $2, $3, $4, $5, $6, $7,
                true, now(), $8, $9, 
                CASE WHEN $9 IS NOT NULL THEN ARRAY[$9]::text[] ELSE ARRAY[]::text[] END, 
                $10
            ) RETURNING to_jsonb(attendees.*)',
            p_field_to_set, v_time_field, v_manual_field, v_by_field
        ) USING 
            p_scanned_name, lower(p_scanned_email), p_phone, p_dept, p_program, p_year, p_event_id,
            p_is_admin_scan, lower(p_scanner_email), v_points_to_award
        INTO v_result;

        RETURN jsonb_build_object('success', true, 'status', 'created', 'attendee', v_result);
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        -- Handle concurrent insert collision cleanly
        SELECT * INTO v_attendee
          FROM public.attendees
         WHERE "eventId" = p_event_id 
           AND (lower(student_email) = lower(p_scanned_email) OR lower(email) = lower(p_scanned_email))
         FOR UPDATE;

        IF v_attendee.id IS NOT NULL THEN
            IF (p_field_to_set = 'morningIn' AND COALESCE(v_attendee."morningIn", false) = true) OR
               (p_field_to_set = 'morningOut' AND COALESCE(v_attendee."morningOut", false) = true) OR
               (p_field_to_set = 'afternoonIn' AND COALESCE(v_attendee."afternoonIn", false) = true) OR
               (p_field_to_set = 'afternoonOut' AND COALESCE(v_attendee."afternoonOut", false) = true) THEN
                RETURN jsonb_build_object('success', false, 'status', 'duplicate', 'name', v_attendee.name);
            END IF;

            EXECUTE format(
                'UPDATE public.attendees SET 
                    %I = true, 
                    %I = now(), 
                    %I = $1, 
                    %I = $2,
                    scanned_by_accounts = CASE 
                        WHEN $2 IS NOT NULL AND NOT ($2 = ANY(COALESCE(scanned_by_accounts, ARRAY[]::text[]))) 
                        THEN array_append(COALESCE(scanned_by_accounts, ARRAY[]::text[]), $2)
                        ELSE COALESCE(scanned_by_accounts, ARRAY[]::text[])
                    END
                 WHERE id = $3 RETURNING to_jsonb(attendees.*)',
                p_field_to_set, v_time_field, v_manual_field, v_by_field
            ) USING p_is_admin_scan, lower(p_scanner_email), v_attendee.id INTO v_result;

            RETURN jsonb_build_object('success', true, 'status', 'updated', 'attendee', v_result);
        END IF;

        RETURN jsonb_build_object('success', false, 'status', 'error', 'error', 'Concurrent collision');
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_attendance_scan TO anon, authenticated, service_role;
