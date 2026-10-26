-- Migration: Gating fines deduction and points award behind event rating and feedback
-- 1. Rename old uuid overload of record_attendance_scan to record_attendance_scan_legacy_uuid to resolve function candidate ambiguity
-- 2. Update record_attendance_scan with proper uuid casting and rating gating
-- 3. Update trg_fines_on_rating_change to update pointsEarned on attendees upon rating completion

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'record_attendance_scan' 
          AND pg_get_function_identity_arguments(oid) LIKE 'p_event_id uuid%'
    ) THEN
        ALTER FUNCTION public.record_attendance_scan(uuid, text, text, text, text, text, text, text, text, boolean) 
        RENAME TO record_attendance_scan_legacy_uuid;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.record_attendance_scan(
    p_event_id text,
    p_scanned_email text,
    p_scanned_name text,
    p_field_to_set text,
    p_is_admin_scan boolean DEFAULT false,
    p_scanner_email text DEFAULT NULL,
    p_phone text DEFAULT '',
    p_dept text DEFAULT '',
    p_program text DEFAULT '',
    p_year text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_event RECORD;
    v_attendee RECORD;
    v_time_field TEXT := p_field_to_set || 'Time';
    v_manual_field TEXT := p_field_to_set || 'Manual';
    v_by_field TEXT := p_field_to_set || 'By';
    v_points_to_award INTEGER := 0;
    v_is_rated BOOLEAN := false;
    v_result JSONB;
BEGIN
    -- 1. Validate event existence
    SELECT id, "providePoints", "pointsAwarded" 
      INTO v_event 
      FROM public.events 
     WHERE id = p_event_id::uuid;

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
     WHERE "eventId" = p_event_id::uuid 
       AND (lower(student_email) = lower(p_scanned_email) OR lower(email) = lower(p_scanned_email))
     FOR UPDATE;

    -- Check if student has already rated this event
    SELECT EXISTS (
        SELECT 1 FROM public.event_ratings 
         WHERE event_id = p_event_id::uuid 
           AND (lower(student_email) = lower(p_scanned_email) OR (v_attendee.name IS NOT NULL AND lower(student_name) = lower(v_attendee.name)))
           AND feedback_text IS NOT NULL AND feedback_text <> ''
    ) INTO v_is_rated;

    IF COALESCE(v_event."providePoints", false) AND v_is_rated THEN
        v_points_to_award := COALESCE(v_event."pointsAwarded", 0);
    ELSE
        v_points_to_award := 0;
    END IF;

    -- 4. Check for duplicate scan
    IF v_attendee.id IS NOT NULL THEN
        IF (p_field_to_set = 'morningIn' AND COALESCE(v_attendee."morningIn", false) = true) OR
           (p_field_to_set = 'morningOut' AND COALESCE(v_attendee."morningOut", false) = true) OR
           (p_field_to_set = 'afternoonIn' AND COALESCE(v_attendee."afternoonIn", false) = true) OR
           (p_field_to_set = 'afternoonOut' AND COALESCE(v_attendee."afternoonOut", false) = true) THEN
            RETURN jsonb_build_object('success', false, 'status', 'duplicate', 'name', v_attendee.name);
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
            p_scanned_name, lower(p_scanned_email), p_phone, p_dept, p_program, p_year, v_event.id,
            p_is_admin_scan, lower(p_scanner_email), v_points_to_award
        INTO v_result;

        RETURN jsonb_build_object('success', true, 'status', 'created', 'attendee', v_result);
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        -- Safely handle concurrent insert collision
        SELECT * INTO v_attendee
          FROM public.attendees
         WHERE "eventId" = p_event_id::uuid 
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
$function$;

CREATE OR REPLACE FUNCTION public.trg_fines_on_rating_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NULL;
    END IF;
    IF (TG_OP = 'DELETE') THEN
        IF OLD.student_email IS NOT NULL THEN
            UPDATE public.attendees
               SET "pointsEarned" = 0
             WHERE "eventId" = OLD.event_id
               AND (lower(student_email) = lower(OLD.student_email) OR lower(email) = lower(OLD.student_email));

            PERFORM public.recalculate_student_fines(OLD.student_email);
        END IF;
    ELSE
        IF NEW.student_email IS NOT NULL THEN
            -- Update pointsEarned on attendees if event provides points and all required sessions are attended
            UPDATE public.attendees a
               SET "pointsEarned" = CASE
                   WHEN e."providePoints" = true AND (
                       (NOT COALESCE(e."morningIn", false) OR COALESCE(a."morningIn", false)) AND
                       (NOT COALESCE(e."morningOut", false) OR COALESCE(a."morningOut", false)) AND
                       (NOT COALESCE(e."afternoonIn", false) OR COALESCE(a."afternoonIn", false)) AND
                       (NOT COALESCE(e."afternoonOut", false) OR COALESCE(a."afternoonOut", false)) AND
                       (COALESCE(e."morningIn", false) OR COALESCE(e."morningOut", false) OR COALESCE(e."afternoonIn", false) OR COALESCE(e."afternoonOut", false))
                   ) THEN COALESCE(e."pointsAwarded", 0)
                   ELSE 0
               END
              FROM public.events e
             WHERE a."eventId" = e.id
               AND a."eventId" = NEW.event_id
               AND (lower(a.student_email) = lower(NEW.student_email) OR lower(a.email) = lower(NEW.student_email));

            PERFORM public.recalculate_student_fines(NEW.student_email);
        END IF;
    END IF;
    RETURN NULL;
END;
$function$;
