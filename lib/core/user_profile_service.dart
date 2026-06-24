import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../firebase_options.dart';
import 'attendee_service.dart';

/// Singleton profile service that extends ChangeNotifier to make user data
/// updates reactive.
///
/// Profile data is persisted in Firestore via the **REST API** (not the
/// cloud_firestore SDK) so that it works correctly on Windows, where the
/// Firebase C++ SDK has a known bug that prevents it from sharing the auth
/// token with the Firestore module.
class UserProfileService extends ChangeNotifier {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  // ── Profile fields (populated from Firestore after login) ────────────────
  String name = '';
  String email = '';
  String phone = '';
  String department = '';
  String program = '';
  String yearLevel = '';

  Timer? _rotationTimer;

  // ── Firestore REST API constants ──────────────────────────────────────────
  static const String _projectId = 'digital-life-app-f82f9';
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  /// Returns the Firestore REST URL for a given user document.
  String _docUrl(String uid) => '$_baseUrl/users/$uid';

  File? _getLocalFile(String uid) {
    if (kIsWeb) return null;
    try {
      String path;
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? '.';
        path = '$appData/DigitalLifeApp';
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '.';
        path = '$home/.digital_life_app';
      } else if (Platform.isAndroid) {
        // On Android, the working directory is the app's private data dir.
        // Fall back to relative path — it resolves inside the app sandbox.
        path = '.';
      } else if (Platform.isIOS) {
        // Use the iOS Documents directory accessible to the sandbox.
        final homeDir = Platform.environment['HOME'] ?? '.';
        path = '$homeDir/Documents';
      } else {
        path = '.';
      }
      final dir = Directory(path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return File('${dir.path}/profile_$uid.json');
    } catch (e) {
      dev.log('UserProfileService — failed to get local file: $e');
      return null;
    }
  }

  Future<void> _loadLocal(String uid) async {
    final file = _getLocalFile(uid);
    if (file == null || !file.existsSync()) return;
    try {
      final content = await file.readAsString();
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
    final file = _getLocalFile(uid);
    if (file == null) return;
    try {
      final data = {
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'program': program,
        'yearLevel': yearLevel,
      };
      await file.writeAsString(jsonEncode(data));
      dev.log('UserProfileService — saved profile locally for uid: $uid');
    } catch (e) {
      dev.log('UserProfileService — failed to save profile locally: $e');
    }
  }

  /// Gets a fresh ID token for the currently signed-in user.
  Future<String?> _getIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      dev.log('UserProfileService — getIdToken failed: $e');
      return null;
    }
  }

  // ── Firestore field encoding / decoding helpers ───────────────────────────

  /// Encodes a map of String values into Firestore REST "fields" format.
  Map<String, dynamic> _encodeFields(Map<String, String> data) {
    return data
        .map((key, value) => MapEntry(key, {'stringValue': value}));
  }

  /// Decodes a Firestore REST response "fields" map into plain String values.
  Map<String, String> _decodeFields(Map<String, dynamic> fields) {
    return fields.map(
      (key, value) => MapEntry(
        key,
        (value as Map<String, dynamic>)['stringValue'] as String? ?? '',
      ),
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Exchanges the Firebase ID token for a Supabase custom JWT via the Edge Function
  /// and sets the Supabase client session.
  Future<void> exchangeFirebaseToken(String firebaseToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://fsczvbsfhuenrzwxtgyq.supabase.co/functions/v1/firebase-token-exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebaseToken': firebaseToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final supabaseToken = body['access_token'];
        await Supabase.instance.client.auth.setSession(supabaseToken);
        dev.log('UserProfileService — Token exchanged, Supabase authenticated successfully.');
      } else {
        dev.log('UserProfileService — Token exchange failed: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('Supabase token exchange returned status ${response.statusCode}');
      }
    } catch (e) {
      dev.log('UserProfileService — Error during token exchange: $e');
      rethrow;
    }
  }

  /// Loads the user's profile from Firestore via REST and notifies listeners.
  Future<void> loadFromFirestore(String uid) async {
    // Load local cache first so UI responds instantly.
    await _loadLocal(uid);
    notifyListeners();

    final token = await _getIdToken();
    if (token == null) {
      dev.log('loadFromFirestore — no auth token, skipping load');
      notifyListeners();
      return;
    }

    // Exchange Firebase token for Supabase session token
    try {
      await exchangeFirebaseToken(token);
    } catch (e) {
      dev.log('loadFromFirestore — token exchange error: $e');
    }

    try {
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      final response = await http.get(
        Uri.parse('${_docUrl(uid)}?key=$apiKey'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final fields = body['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final data = _decodeFields(fields);
          name = data['name'] ?? '';
          email = data['email'] ?? '';
          phone = data['phone'] ?? '';
          department = data['department'] ?? '';
          program = data['program'] ?? '';
          yearLevel = data['yearLevel'] ?? '';
          dev.log('loadFromFirestore — loaded profile for uid: $uid');
          await _saveLocal(uid);
        }
      } else if (response.statusCode == 404) {
        dev.log('loadFromFirestore — no document found for uid: $uid');
      } else {
        dev.log('loadFromFirestore — HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      dev.log('loadFromFirestore — error: $e');
    }

    notifyListeners();

    // Start listening for attendee updates keyed to this user's email.
    if (email.isNotEmpty) {
      await AttendeeService().startListening(email);
    }
  }

  /// Writes the current profile fields to Firestore via REST.
  Future<void> saveToFirestore(String uid) async {
    // Persist changes locally first to guarantee saving even if offline/Firestore error.
    await _saveLocal(uid);

    final token = await _getIdToken();
    if (token == null) {
      dev.log('saveToFirestore — no auth token, aborting');
      return;
    }

    // PATCH with updateMask ensures we only write these specific fields.
    final fields = _encodeFields({
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'program': program,
      'yearLevel': yearLevel,
    });

    final updateMask = fields.keys
        .map((k) => 'updateMask.fieldPaths=$k')
        .join('&');

    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final url = Uri.parse('${_docUrl(uid)}?key=$apiKey&$updateMask');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': 'projects/$_projectId/databases/(default)/documents/users/$uid',
          'fields': fields,
        }),
      );

      if (response.statusCode == 200) {
        dev.log('saveToFirestore — saved profile to Firestore for uid: $uid');
      } else {
        dev.log('saveToFirestore — Firestore REST save returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      dev.log('saveToFirestore — Firestore REST save error: $e');
    }
  }

  /// Updates the in-memory profile and persists it to Firestore.
  Future<void> updateProfile({
    required String uid,
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
    await saveToFirestore(uid);
    await saveToSupabase(uid);
  }

  // ── Supabase integration ──────────────────────────────────────────────────

  /// Returns true if this Firebase UID has no row in the Supabase users table,
  /// meaning the user has not yet completed their registration profile.
  Future<bool> checkIsFirstLogin(String uid) async {
    final result = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('uid', uid)
        .maybeSingle();
    return result == null;
  }

  /// Saves the current timestamp to the local cache file as the last login time.
  Future<void> saveSessionTimestamp(String uid) async {
    final file = _getLocalFile(uid);
    if (file == null) return;
    try {
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      }
      data['lastLoginAt'] = DateTime.now().millisecondsSinceEpoch;
      await file.writeAsString(jsonEncode(data));
      dev.log('UserProfileService — saved lastLoginAt for uid: $uid');
    } catch (e) {
      dev.log('UserProfileService — failed to save session timestamp: $e');
    }
  }

  /// Checks if the cached last login timestamp is older than 7 days.
  Future<bool> isSessionExpired(String uid) async {
    final file = _getLocalFile(uid);
    if (file == null || !file.existsSync()) return false;
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final lastLoginAt = data['lastLoginAt'] as int?;
      if (lastLoginAt == null) return false;
      
      final loginTime = DateTime.fromMillisecondsSinceEpoch(lastLoginAt);
      final difference = DateTime.now().difference(loginTime);
      return difference.inDays >= 7;
    } catch (e) {
      dev.log('UserProfileService — failed to check session expiry: $e');
      return false;
    }
  }

  /// Upserts the current profile fields to the Supabase users table.
  /// Throws on failure so callers can surface the error.
  Future<void> saveToSupabase(String uid) async {
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
