import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'attendee_service.dart';
import 'notification_service.dart';

/// Singleton profile service that extends ChangeNotifier to make user data
/// updates reactive.
///
/// Profile data is persisted in Supabase Auth and database.
class UserProfileService extends ChangeNotifier {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  // ── Profile fields (populated from Supabase after login) ────────────────
  String name = '';
  String email = '';
  String phone = '';
  String department = '';
  String program = '';
  String yearLevel = '';

  Timer? _rotationTimer;
  DateTime? _lastNotifiedDate;

  Future<void> _loadLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString('profile_$uid');
      if (content == null) return;
      final data = jsonDecode(content) as Map<String, dynamic>;
      name = data['name'] ?? '';
      email = data['email'] ?? '';
      phone = data['phone'] ?? '';
      department = data['department'] ?? '';
      program = data['program'] ?? '';
      yearLevel = data['yearLevel'] ?? '';
      dev.log('UserProfileService — loaded profile locally for uid: $uid');
    } catch (e) {
      dev.log('UserProfileService — failed to load profile locally: $e');
    }
  }

  Future<void> _saveLocal(String uid) async {
    try {
      final data = {
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'program': program,
        'yearLevel': yearLevel,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_$uid', jsonEncode(data));
      dev.log('UserProfileService — saved profile locally for uid: $uid');
    } catch (e) {
      dev.log('UserProfileService — failed to save profile locally: $e');
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Loads the user's profile from Supabase and notifies listeners.
  Future<void> loadProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      dev.log('loadProfile — no auth user, skipping load');
      notifyListeners();
      return;
    }

    // Load local cache first so UI responds instantly.
    await _loadLocal(uid);
    notifyListeners();

    try {
      final row = await Supabase.instance.client
          .from('users')
          .select()
          .eq('uid', uid)
          .maybeSingle();

      if (row != null) {
        name = row['name'] ?? '';
        email = row['email'] ?? '';
        phone = row['phone'] ?? '';
        department = row['department'] ?? '';
        program = row['program'] ?? '';
        yearLevel = row['year_level'] ?? '';
        dev.log('UserProfileService — loaded profile from Supabase for uid: $uid');
        await _saveLocal(uid);
      }
    } catch (e) {
      dev.log('UserProfileService — loadProfile error: $e');
    }

    notifyListeners();

    // Start listening for attendee updates keyed to this user's email.
    if (email.isNotEmpty) {
      await AttendeeService().startListening(email);
    }
  }

  /// Updates the in-memory profile and persists it to Supabase.
  Future<void> updateProfile({
    required String newName,
    required String newEmail,
    required String newPhone,
    required String newDept,
    required String newProgram,
    required String newYearLevel,
  }) async {
    name = newName;
    email = newEmail;
    phone = newPhone;
    department = newDept;
    program = newProgram;
    yearLevel = newYearLevel;
    notifyListeners();
    await saveToSupabase();
  }

  // ── Supabase integration ──────────────────────────────────────────────────

  /// Returns true if this Supabase User ID has no row or an incomplete row in the users table,
  /// meaning the user has not yet completed their registration profile.
  Future<bool> checkIsFirstLogin() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return true;

    try {
      final result = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('uid', uid)
          .maybeSingle();

      if (result == null) return true;
      final storedName = result['name'] as String?;
      return storedName == null || storedName.trim().isEmpty;
    } catch (e) {
      dev.log('UserProfileService — checkIsFirstLogin error: $e');
      return true;
    }
  }

  /// Checks if the current Supabase session is expired.
  Future<bool> isSessionExpired() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return true;
    return session.isExpired;
  }

  /// Upserts the current profile fields to the Supabase users table.
  /// Throws on failure so callers can surface the error.
  Future<void> saveToSupabase() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      dev.log('saveToSupabase — no auth user, aborting');
      return;
    }

    // Save locally first
    await _saveLocal(uid);

    await Supabase.instance.client.from('users').upsert(
      {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'program': program,
        'year_level': yearLevel,
      },
      onConflict: 'uid',   // upsert on uid, not the auto-generated id PK
    );
    dev.log('UserProfileService — saved profile to Supabase for uid: $uid');
  }

  /// Clears all fields (called on sign-out).
  void clearProfile() {
    _clearFields();
    AttendeeService().stopListening();
    Supabase.instance.client.auth.signOut().catchError((e) {
      dev.log('UserProfileService — failed to sign out of Supabase: $e');
    });
    notifyListeners();
  }

  void _clearFields() {
    name = '';
    email = '';
    phone = '';
    department = '';
    program = '';
    yearLevel = '';
  }

  /// Starts a periodic check to detect day changes and notifies listeners
  /// to update the QR code.
  void startDailyRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      // Only notify if the day has actually changed
      if (_lastNotifiedDate != null &&
          (_lastNotifiedDate!.day != now.day ||
           _lastNotifiedDate!.month != now.month ||
           _lastNotifiedDate!.year != now.year)) {
        NotificationService.showLocalNotification(
          'QR Code Updated 🔄',
          'Your attendance QR code has been refreshed for today.',
        );
      }
      _lastNotifiedDate = now;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  /// Encodes profile details along with a daily expiration timestamp into
  /// JSON for the QR code.
  String toQrData() {
    final now = DateTime.now();
    final dayTimestamp =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return jsonEncode({
      'name': name,
      'email': email,
      'phone': phone,
      'dept': department,
      'program': program,
      'year': yearLevel,
      'expiresAt': dayTimestamp,
    });
  }
}
