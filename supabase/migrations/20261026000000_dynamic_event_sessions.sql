-- Migration: 20261026000000_dynamic_event_sessions.sql
-- Description: Dynamic attendance sessions and fines calculation per configured session.

CREATE OR REPLACE FUNCTION public.recalculate_student_fines(target_student_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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

    -- Calculate accumulated dues and total points for compulsory events based on configured event sessions
    SELECT 
        COALESCE(SUM(
            (CASE WHEN COALESCE(e."morningIn", false) THEN 
                (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningIn", false) THEN 0 ELSE 50 END) 
             ELSE 0 END) +
            (CASE WHEN COALESCE(e."morningOut", false) THEN 
                (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."morningOut", false) THEN 0 ELSE 50 END) 
             ELSE 0 END) +
            (CASE WHEN COALESCE(e."afternoonIn", false) THEN 
                (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonIn", false) THEN 0 ELSE 50 END) 
             ELSE 0 END) +
            (CASE WHEN COALESCE(e."afternoonOut", false) THEN 
                (CASE WHEN (r.id IS NOT NULL) AND COALESCE(a."afternoonOut", false) THEN 0 ELSE 50 END) 
             ELSE 0 END)
        ), 0),
        COALESCE(SUM(
            CASE 
                WHEN e."providePoints" = true AND r.id IS NOT NULL AND (
                    (NOT COALESCE(e."morningIn", false) OR COALESCE(a."morningIn", false)) AND
                    (NOT COALESCE(e."morningOut", false) OR COALESCE(a."morningOut", false)) AND
                    (NOT COALESCE(e."afternoonIn", false) OR COALESCE(a."afternoonIn", false)) AND
                    (NOT COALESCE(e."afternoonOut", false) OR COALESCE(a."afternoonOut", false)) AND
                    (COALESCE(e."morningIn", false) OR COALESCE(e."morningOut", false) OR COALESCE(e."afternoonIn", false) OR COALESCE(e."afternoonOut", false))
                ) THEN COALESCE(e."pointsAwarded", 0)
                ELSE 0
            END
        ), 0)
    INTO v_dues, v_points
    FROM public.events e
    LEFT JOIN (
        SELECT "eventId", "morningIn", "morningOut", "afternoonIn", "afternoonOut"
        FROM public.attendees 
        WHERE lower(COALESCE(student_email, email)) = lower(target_student_email)
    ) a ON a."eventId" = e.id
    LEFT JOIN (
        SELECT event_id, id
        FROM public.event_ratings
        WHERE lower(student_email) = lower(target_student_email)
        UNION
        SELECT event_id, id
        FROM public.event_ratings
        WHERE v_name <> '' AND lower(student_name) = lower(v_name)
    ) r ON r.event_id = e.id
    WHERE (e."isCompulsory" = true OR e."isCompulsory" IS NULL)
      AND (e."isVoid" = false OR e."isVoid" IS NULL);

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
$function$;

CREATE OR REPLACE FUNCTION public.recalculate_all_student_fines()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    WITH attendee_lookup AS (
        SELECT 
            "eventId", 
            lower(COALESCE(student_email, email)) AS email,
            "morningIn", "morningOut", "afternoonIn", "afternoonOut"
        FROM public.attendees
    ),
    rated_lookup AS (
        SELECT DISTINCT event_id, lower(student_email) AS email
        FROM public.event_ratings
        WHERE student_email IS NOT NULL AND student_email <> ''
        UNION
        SELECT DISTINCT r.event_id, lower(u.email) AS email
        FROM public.event_ratings r
        JOIN public.users u ON lower(u.name) = lower(r.student_name)
        WHERE r.student_email IS NULL OR r.student_email = ''
    )
    INSERT INTO public.student_fines_summary (
        student_uid, student_email, student_name, accumulated_dues, hours_rendered, total_points, last_updated
    )
    SELECT 
        u.uid AS student_uid,
        lower(u.email) AS student_email,
        u.name AS student_name,
        COALESCE(SUM(
            (CASE WHEN COALESCE(e."morningIn", false) THEN 
                (CASE WHEN (r.email IS NOT NULL) AND COALESCE(a."morningIn", false) THEN 0 ELSE 50 END) 
             ELSE 0 END) +
            (CASE WHEN COALESCE(e."morningOut", false) THEN 
                (CASE WHEN (r.email IS NOT NULL) AND COALESCE(a."morningOut", false) THEN 0 ELSE 50 END) 
             ELSE 0 END) +
            (CASE WHEN COALESCE(e."afternoonIn", false) THEN 
                (CASE WHEN (r.email IS NOT NULL) AND COALESCE(a."afternoonIn", false) THEN 0 ELSE 50 END) 
             ELSE 0 END) +
            (CASE WHEN COALESCE(e."afternoonOut", false) THEN 
                (CASE WHEN (r.email IS NOT NULL) AND COALESCE(a."afternoonOut", false) THEN 0 ELSE 50 END) 
             ELSE 0 END)
        ), 0) AS accumulated_dues,
        0 AS hours_rendered,
        COALESCE(SUM(
            CASE 
                WHEN e."providePoints" = true AND r.email IS NOT NULL AND (
                    (NOT COALESCE(e."morningIn", false) OR COALESCE(a."morningIn", false)) AND
                    (NOT COALESCE(e."morningOut", false) OR COALESCE(a."morningOut", false)) AND
                    (NOT COALESCE(e."afternoonIn", false) OR COALESCE(a."afternoonIn", false)) AND
                    (NOT COALESCE(e."afternoonOut", false) OR COALESCE(a."afternoonOut", false)) AND
                    (COALESCE(e."morningIn", false) OR COALESCE(e."morningOut", false) OR COALESCE(e."afternoonIn", false) OR COALESCE(e."afternoonOut", false))
                ) THEN COALESCE(e."pointsAwarded", 0)
                ELSE 0
            END
        ), 0) AS total_points,
        now() AS last_updated
    FROM public.users u
    CROSS JOIN public.events e
    LEFT JOIN attendee_lookup a ON a."eventId" = e.id AND a.email = lower(u.email)
    LEFT JOIN rated_lookup r ON r.event_id = e.id AND r.email = lower(u.email)
    WHERE (e."isCompulsory" = true OR e."isCompulsory" IS NULL)
      AND (e."isVoid" = false OR e."isVoid" IS NULL)
    GROUP BY u.uid, lower(u.email), u.name
    ON CONFLICT (student_uid) DO UPDATE SET
        student_name = EXCLUDED.student_name,
        student_email = EXCLUDED.student_email,
        accumulated_dues = EXCLUDED.accumulated_dues,
        hours_rendered = EXCLUDED.hours_rendered,
        total_points = EXCLUDED.total_points,
        last_updated = now();
END;
$function$;
