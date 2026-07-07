import 'dart:developer' as dev;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages session lifecycle and invalidation.
///
/// Checks the following conditions on startup and terminates the active
/// Supabase session if any are met:
///
/// 1. **App installed / updated** — stored build number differs from current.
/// 2. **Token expired** — handled upstream by the splash screen, not here.
/// 3. **User changed on device** — stored uid differs from session uid.
/// 4. **Manual sign-out** — handled by [clearSessionData].
/// 5. **Extended inactivity (3 days)** — last-active timestamp is too old.
class SessionService {
  SessionService._internal();
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _keyLastBuildNumber  = 'session_last_build_number';
  static const _keyLastUserId       = 'session_last_user_id';
  static const _keyLastActiveMs     = 'session_last_active_ms';

  static const _inactivityLimitDays = 3;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks all invalidation conditions and signs the user out if any are met.
  ///
  /// Returns `true` if the session was invalidated (caller should route to
  /// LoginScreen), or `false` if the session is still valid and can proceed.
  Future<bool> checkAndInvalidateIfNeeded() async {
    final session = Supabase.instance.client.auth.currentSession;

    // No session — nothing to invalidate; splash will handle routing.
    if (session == null) return false;

    final prefs        = await SharedPreferences.getInstance();
    final packageInfo  = await PackageInfo.fromPlatform();
    final currentBuild = packageInfo.buildNumber;
    final currentUid   = session.user.id;
    final nowMs        = DateTime.now().millisecondsSinceEpoch;

    final storedBuild  = prefs.getString(_keyLastBuildNumber);
    final storedUid    = prefs.getString(_keyLastUserId);
    final lastActiveMs = prefs.getInt(_keyLastActiveMs) ?? nowMs;

    // ── Condition 1: App installed or updated ─────────────────────────────
    if (storedBuild != null && storedBuild != currentBuild) {
      dev.log('SessionService — build changed ($storedBuild → $currentBuild): invalidating');
      await _invalidate(reason: 'app_updated');
      return true;
    }

    // ── Condition 3: Different user on same device ────────────────────────
    if (storedUid != null && storedUid != currentUid) {
      dev.log('SessionService — user changed ($storedUid → $currentUid): invalidating');
      await _invalidate(reason: 'user_changed');
      return true;
    }

    // ── Condition 5: Inactivity exceeded 3 days ───────────────────────────
    final inactiveDuration = Duration(milliseconds: nowMs - lastActiveMs);
    if (inactiveDuration.inDays >= _inactivityLimitDays) {
      dev.log('SessionService — inactive ${inactiveDuration.inDays} days: invalidating');
      await _invalidate(reason: 'inactivity');
      return true;
    }

    // ── All checks passed — persist current identity & build number ───────
    await prefs.setString(_keyLastBuildNumber, currentBuild);
    await prefs.setString(_keyLastUserId, currentUid);

    return false;
  }

  /// Records the current timestamp as the last active time.
  ///
  /// Call this each time a valid session successfully reaches [MainShell].
  Future<void> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastActiveMs, DateTime.now().millisecondsSinceEpoch);
    dev.log('SessionService — activity recorded');
  }

  /// Wipes all stored session data.
  ///
  /// Call this on manual sign-out so the next user on the same device
  /// starts with a completely clean state.
  Future<void> clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastBuildNumber);
    await prefs.remove(_keyLastUserId);
    await prefs.remove(_keyLastActiveMs);
    dev.log('SessionService — session data cleared');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _invalidate({required String reason}) async {
    await clearSessionData();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      dev.log('SessionService — signOut failed during invalidation ($reason): $e');
    }
  }
}
