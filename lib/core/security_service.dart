import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityService {
  factory SecurityService() => _instance;
  SecurityService._internal();
  static final SecurityService _instance = SecurityService._internal();

  static const String _keyResetTimestamps = 'sec_reset_timestamps';
  static const String _keyLoginAttempts = 'sec_login_attempts';
  static const String _keyCooldownUntil = 'sec_cooldown_until';

  /// Check if a password reset request is allowed (max 5 requests per rolling 24 hours).
  Future<bool> canRequestPasswordReset() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamps = prefs.getStringList(_keyResetTimestamps) ?? [];

    // Filter timestamps within the last 24 hours
    final oneDayAgo = now - const Duration(hours: 24).inMilliseconds;
    final activeTimestamps = timestamps
        .map(int.parse)
        .where((ts) => ts > oneDayAgo)
        .toList();

    return activeTimestamps.length < 5;
  }

  /// Record a password reset request.
  Future<void> recordPasswordResetRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamps = prefs.getStringList(_keyResetTimestamps) ?? [];

    final oneDayAgo = now - const Duration(hours: 24).inMilliseconds;
    final activeTimestamps = timestamps
        .map(int.parse)
        .where((ts) => ts > oneDayAgo)
        .map((ts) => ts.toString())
        .toList();

    activeTimestamps.add(now.toString());
    await prefs.setStringList(_keyResetTimestamps, activeTimestamps);
  }

  /// Get the number of remaining password reset requests (out of 5).
  Future<int> getRemainingResetRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamps = prefs.getStringList(_keyResetTimestamps) ?? [];

    final oneDayAgo = now - const Duration(hours: 24).inMilliseconds;
    final activeTimestamps = timestamps
        .map(int.parse)
        .where((ts) => ts > oneDayAgo)
        .toList();

    final remaining = 5 - activeTimestamps.length;
    return remaining < 0 ? 0 : remaining;
  }

  /// Get remaining cooldown duration for login (in seconds). Returns 0 if no cooldown.
  Future<int> getLoginCooldownRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownUntil = prefs.getInt(_keyCooldownUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (cooldownUntil > now) {
      return ((cooldownUntil - now) / 1000).ceil();
    }
    return 0;
  }

  /// Record a login attempt.
  /// If [success] is true, resets the failure count and cooldown.
  /// If [success] is false, increments failure count and updates cooldown.
  Future<void> recordLoginAttempt(bool success) async {
    final prefs = await SharedPreferences.getInstance();
    if (success) {
      await prefs.setInt(_keyLoginAttempts, 0);
      await prefs.setInt(_keyCooldownUntil, 0);
      return;
    }

    final attempts = (prefs.getInt(_keyLoginAttempts) ?? 0) + 1;
    await prefs.setInt(_keyLoginAttempts, attempts);

    int cooldownMinutes = 0;
    if (attempts >= 15) {
      cooldownMinutes = 60; // 1 hour cooldown
    } else if (attempts >= 10) {
      cooldownMinutes = 5;  // 5 minutes cooldown
    } else if (attempts >= 5) {
      cooldownMinutes = 1;  // 1 minute cooldown
    }

    if (cooldownMinutes > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cooldownUntil = now + Duration(minutes: cooldownMinutes).inMilliseconds;
      await prefs.setInt(_keyCooldownUntil, cooldownUntil);
    }
  }

  /// Set an explicit cooldown duration (e.g. when HTTP 429 rate limit is encountered).
  Future<void> recordRateLimitHit([int seconds = 60]) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownUntil = now + Duration(seconds: seconds).inMilliseconds;
    await prefs.setInt(_keyCooldownUntil, cooldownUntil);
  }

  /// Check server-side rate limit table via PostgreSQL RPC (0 bcrypt computation).
  /// Returns a map with 'allowed' (bool), 'remaining_seconds' (int), and 'message' (String).
  Future<Map<String, dynamic>> checkServerRateLimit(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return {'allowed': true};

    try {
      final res = await Supabase.instance.client.rpc(
        'check_auth_rate_limit',
        params: {'p_identifier': clean},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'allowed': true};
    } catch (_) {
      // If server RPC is unreachable, gracefully fall back to local device rate limit
      return {'allowed': true};
    }
  }

  /// Record auth attempt on server-side rate limit table via PostgreSQL RPC.
  Future<void> recordServerAttempt(String email, bool success) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return;

    try {
      await Supabase.instance.client.rpc(
        'record_auth_attempt',
        params: {'p_identifier': clean, 'p_success': success},
      );
    } catch (_) {
      // Gracefully ignore server logging failure
    }
  }

  /// Helper to get current login attempt count
  Future<int> getLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLoginAttempts) ?? 0;
  }

  /// Clears rate-limiting state ONLY after an explicit administrative unlock or successful session.
  /// (Does not wipe on unauthenticated screen mount to prevent cooldown bypass).
  Future<void> resetForNewSession() async {
    // Intentionally keep device cooldown intact so screen reload cannot bypass lockout
  }

  /// Force clear cooldown (used on successful login or explicit user sign-out).
  Future<void> clearCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoginAttempts);
    await prefs.remove(_keyCooldownUntil);
  }
}
