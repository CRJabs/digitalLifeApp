import 'package:shared_preferences/shared_preferences.dart';

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

  /// Helper to get current login attempt count
  Future<int> getLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLoginAttempts) ?? 0;
  }
}
