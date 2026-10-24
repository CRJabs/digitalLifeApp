-- Migration: 20261024000000_auth_rate_limiting.sql
-- Description: Create auth_rate_limits table and RPC functions for fast, zero-bcrypt rate limiting

CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
    identifier text PRIMARY KEY,
    failed_attempts integer DEFAULT 0,
    locked_until timestamptz,
    last_attempt_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_locked ON public.auth_rate_limits(identifier, locked_until);

-- Function to check if an identifier/email is currently locked out
CREATE OR REPLACE FUNCTION public.check_auth_rate_limit(p_identifier text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_id text := lower(trim(p_identifier));
    v_record public.auth_rate_limits%ROWTYPE;
    v_now timestamptz := now();
    v_remaining integer;
BEGIN
    IF v_clean_id IS NULL OR v_clean_id = '' THEN
        RETURN jsonb_build_object('allowed', true);
    END IF;

    SELECT * INTO v_record FROM public.auth_rate_limits WHERE identifier = v_clean_id;

    IF FOUND AND v_record.locked_until IS NOT NULL AND v_record.locked_until > v_now THEN
        v_remaining := GREATEST(1, EXTRACT(EPOCH FROM (v_record.locked_until - v_now))::integer);
        RETURN jsonb_build_object(
            'allowed', false,
            'remaining_seconds', v_remaining,
            'failed_attempts', v_record.failed_attempts,
            'message', 'Account temporarily locked due to excessive failed attempts. Please wait ' || v_remaining || ' seconds.'
        );
    END IF;

    RETURN jsonb_build_object('allowed', true);
END;
$$;

-- Function to record success or failure
CREATE OR REPLACE FUNCTION public.record_auth_attempt(p_identifier text, p_success boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_id text := lower(trim(p_identifier));
    v_record public.auth_rate_limits%ROWTYPE;
    v_now timestamptz := now();
    v_attempts integer := 1;
    v_lock_seconds integer := 0;
    v_locked_until timestamptz := NULL;
BEGIN
    IF v_clean_id IS NULL OR v_clean_id = '' THEN
        RETURN jsonb_build_object('success', true);
    END IF;

    IF p_success THEN
        -- Reset on successful login
        UPDATE public.auth_rate_limits
        SET failed_attempts = 0,
            locked_until = NULL,
            last_attempt_at = v_now
        WHERE identifier = v_clean_id;
        
        RETURN jsonb_build_object('success', true, 'status', 'cleared');
    END IF;

    -- On failed attempt
    SELECT * INTO v_record FROM public.auth_rate_limits WHERE identifier = v_clean_id;

    IF NOT FOUND THEN
        v_attempts := 1;
    ELSE
        -- If previous failure was over 15 minutes ago and not locked, reset count
        IF v_record.last_attempt_at < (v_now - INTERVAL '15 minutes') AND (v_record.locked_until IS NULL OR v_record.locked_until <= v_now) THEN
            v_attempts := 1;
        ELSE
            v_attempts := v_record.failed_attempts + 1;
        END IF;
    END IF;

    -- Progressive cooldown schedule:
    -- 5 attempts  -> 1 minute cooldown
    -- 7 attempts  -> 5 minutes cooldown
    -- 10 attempts -> 15 minutes cooldown
    -- 15+ attempts -> 30 minutes cooldown
    IF v_attempts >= 15 THEN
        v_lock_seconds := 1800; -- 30 minutes
    ELSIF v_attempts >= 10 THEN
        v_lock_seconds := 900;  -- 15 minutes
    ELSIF v_attempts >= 7 THEN
        v_lock_seconds := 300;  -- 5 minutes
    ELSIF v_attempts >= 5 THEN
        v_lock_seconds := 60;   -- 1 minute
    END IF;

    IF v_lock_seconds > 0 THEN
        v_locked_until := v_now + (v_lock_seconds || ' seconds')::interval;
    END IF;

    INSERT INTO public.auth_rate_limits (identifier, failed_attempts, locked_until, last_attempt_at)
    VALUES (v_clean_id, v_attempts, v_locked_until, v_now)
    ON CONFLICT (identifier) DO UPDATE SET
        failed_attempts = v_attempts,
        locked_until = v_locked_until,
        last_attempt_at = v_now;

    RETURN jsonb_build_object(
        'success', true,
        'failed_attempts', v_attempts,
        'locked', v_lock_seconds > 0,
        'remaining_seconds', v_lock_seconds
    );
END;
$$;

-- Grant permissions for anon and authenticated users
GRANT SELECT, INSERT, UPDATE ON public.auth_rate_limits TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_auth_rate_limit(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_auth_attempt(text, boolean) TO anon, authenticated;
