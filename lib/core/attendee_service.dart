import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a single row in the `attendees` table.
class AttendeeRecord {
  final String id;
  final String eventId;
  final String name;
  final bool morningIn;
  final bool morningOut;
  final bool afternoonIn;
  final bool afternoonOut;
  final DateTime createdAt;

  const AttendeeRecord({
    required this.id,
    required this.eventId,
    required this.name,
    required this.morningIn,
    required this.morningOut,
    required this.afternoonIn,
    required this.afternoonOut,
    required this.createdAt,
  });

  factory AttendeeRecord.fromJson(Map<String, dynamic> json) {
    return AttendeeRecord(
      id: json['id'] as String? ?? '',
      eventId: json['eventId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      morningIn: json['morningIn'] as bool? ?? false,
      morningOut: json['morningOut'] as bool? ?? false,
      afternoonIn: json['afternoonIn'] as bool? ?? false,
      afternoonOut: json['afternoonOut'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// A recent-activity entry derived from an attendee record change.
class RecentActivityItem {
  final String eventName;
  final String detail;
  final DateTime timestamp;

  const RecentActivityItem({
    required this.eventName,
    required this.detail,
    required this.timestamp,
  });
}

/// Represents detailed information about missed checks for an event.
class MissingCheckInfo {
  final String eventName;
  final String date;
  final List<String> missingSlots;
  final double totalFine;

  MissingCheckInfo({
    required this.eventName,
    required this.date,
    required this.missingSlots,
    required this.totalFine,
  });
}

/// Singleton that subscribes to Supabase realtime updates on the `attendees`
/// table for the currently logged-in user (matched by name), and notifies
/// listeners so both [HomeScreen], [ActivityScreen], and [FinesScreen] stay in sync.
class AttendeeService extends ChangeNotifier {
  static final AttendeeService _instance = AttendeeService._internal();
  factory AttendeeService() => _instance;
  AttendeeService._internal();

  // ── Public state ─────────────────────────────────────────────────────────

  /// All attendee records for the current user (keyed by eventId for fast lookup).
  final Map<String, AttendeeRecord> attendeesByEvent = {};

  /// Recent activity items, newest first (up to [_maxRecentItems]).
  final List<RecentActivityItem> recentActivity = [];

  static const int _maxRecentItems = 10;

  /// Current user's outstanding dues.
  double outstandingDues = 0.0;

  /// Current user's notices/announcements from administrators.
  String studentNotice = '';

  // ── Private ───────────────────────────────────────────────────────────────

  RealtimeChannel? _channel;
  RealtimeChannel? _finesChannel;
  String? _currentUserName;
  List<dynamic> _cachedEvents = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start listening for attendee changes for [userName].
  /// Call this after a successful login, once the user profile is loaded.
  Future<void> startListening(String userName) async {
    if (userName.isEmpty) return;
    if (_currentUserName == userName) return; // already listening
    _currentUserName = userName;

    // Load initial records
    await _fetchAll(userName);

    // Calculate initial dues & fetch notices
    await calculateAndSyncDues();

    // Subscribe to realtime updates
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('attendees:$userName')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'name',
            value: userName,
          ),
          callback: (payload) => _handleChange(payload),
        )
        .subscribe();

    // Subscribe to realtime student_fines changes
    _finesChannel?.unsubscribe();
    _finesChannel = Supabase.instance.client
        .channel('student_fines:$userName')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'student_fines',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_name',
            value: userName,
          ),
          callback: (payload) {
            final newRec = payload.newRecord;
            if (newRec.isNotEmpty) {
              studentNotice = newRec['notices'] as String? ?? '';
              final duesVal = newRec['outstanding_dues'];
              if (duesVal is num) {
                outstandingDues = duesVal.toDouble();
              }
              notifyListeners();
            }
          },
        )
        .subscribe();

    dev.log('AttendeeService — subscribed for user: $userName');
  }

  /// Stop listening and clear state. Call on sign-out.
  Future<void> stopListening() async {
    _channel?.unsubscribe();
    _channel = null;
    _finesChannel?.unsubscribe();
    _finesChannel = null;
    _currentUserName = null;
    attendeesByEvent.clear();
    recentActivity.clear();
    _cachedEvents.clear();
    outstandingDues = 0.0;
    studentNotice = '';
    notifyListeners();
  }

  /// Returns the attendee record for a specific [eventId], or null if none.
  AttendeeRecord? recordFor(String eventId) => attendeesByEvent[eventId];

  /// Calculates outstanding dues based on required fields of past and current events
  /// compared with user attendee records, and upserts it to Supabase.
  Future<void> calculateAndSyncDues() async {
    if (_currentUserName == null || _currentUserName!.isEmpty) return;
    try {
      // 1. Fetch events
      final eventsData = await Supabase.instance.client
          .from('events')
          .select()
          .order('created_at', ascending: false);
      _cachedEvents = eventsData as List<dynamic>;

      // 2. Fetch notices
      final fineRecord = await Supabase.instance.client
          .from('student_fines')
          .select()
          .eq('student_name', _currentUserName!)
          .maybeSingle();

      if (fineRecord != null) {
        studentNotice = fineRecord['notices'] as String? ?? '';
      } else {
        studentNotice = '';
      }

      // 3. Compute outstanding dues
      double computedDues = 0.0;
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      for (final eventJson in _cachedEvents) {
        final eventId = eventJson['id'] as String;
        final eventDateStr = eventJson['date'] as String? ?? '';

        DateTime? eventDate;
        try {
          eventDate = DateTime.parse(eventDateStr);
        } catch (_) {}

        if (eventDate == null) continue;

        // Fines are only for finished or currently happening events (today or past)
        final eventCompareDate = DateTime(eventDate.year, eventDate.month, eventDate.day);
        if (eventCompareDate.isAfter(todayDate)) {
          continue;
        }

        final morningInReq = eventJson['morningIn'] as bool? ?? false;
        final morningOutReq = eventJson['morningOut'] as bool? ?? false;
        final afternoonInReq = eventJson['afternoonIn'] as bool? ?? false;
        final afternoonOutReq = eventJson['afternoonOut'] as bool? ?? false;

        final attendee = recordFor(eventId);

        if (morningInReq && (attendee == null || !attendee.morningIn)) {
          computedDues += 25.0;
        }
        if (morningOutReq && (attendee == null || !attendee.morningOut)) {
          computedDues += 25.0;
        }
        if (afternoonInReq && (attendee == null || !attendee.afternoonIn)) {
          computedDues += 25.0;
        }
        if (afternoonOutReq && (attendee == null || !attendee.afternoonOut)) {
          computedDues += 25.0;
        }
      }

      outstandingDues = computedDues;

      // 4. Save/upsert to database
      await Supabase.instance.client.from('student_fines').upsert({
        'student_name': _currentUserName!,
        'outstanding_dues': outstandingDues,
        'notices': studentNotice,
        'updated_at': DateTime.now().toIso8601String(),
      });

      notifyListeners();
    } catch (e) {
      dev.log('AttendeeService — calculateAndSyncDues error: $e');
    }
  }

  /// Compiles details of all missing checks for events that are today or in the past.
  List<MissingCheckInfo> getMissingChecks() {
    final list = <MissingCheckInfo>[];
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    for (final eventJson in _cachedEvents) {
      final eventId = eventJson['id'] as String;
      final eventName = eventJson['eventName'] as String? ?? 'Unknown Event';
      final eventDateStr = eventJson['date'] as String? ?? '';

      DateTime? eventDate;
      try {
        eventDate = DateTime.parse(eventDateStr);
      } catch (_) {}

      if (eventDate == null) continue;

      final eventCompareDate = DateTime(eventDate.year, eventDate.month, eventDate.day);
      if (eventCompareDate.isAfter(todayDate)) {
        continue;
      }

      final morningInReq = eventJson['morningIn'] as bool? ?? false;
      final morningOutReq = eventJson['morningOut'] as bool? ?? false;
      final afternoonInReq = eventJson['afternoonIn'] as bool? ?? false;
      final afternoonOutReq = eventJson['afternoonOut'] as bool? ?? false;

      final attendee = recordFor(eventId);
      final missingSlots = <String>[];

      if (morningInReq && (attendee == null || !attendee.morningIn)) {
        missingSlots.add('Morning Check-in');
      }
      if (morningOutReq && (attendee == null || !attendee.morningOut)) {
        missingSlots.add('Morning Check-out');
      }
      if (afternoonInReq && (attendee == null || !attendee.afternoonIn)) {
        missingSlots.add('Afternoon Check-in');
      }
      if (afternoonOutReq && (attendee == null || !attendee.afternoonOut)) {
        missingSlots.add('Afternoon Check-out');
      }

      if (missingSlots.isNotEmpty) {
        list.add(MissingCheckInfo(
          eventName: eventName,
          date: eventDateStr,
          missingSlots: missingSlots,
          totalFine: missingSlots.length * 25.0,
        ));
      }
    }
    return list;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _fetchAll(String userName) async {
    try {
      final data = await Supabase.instance.client
          .from('attendees')
          .select()
          .eq('name', userName);

      final records = (data as List<dynamic>)
          .map((j) => AttendeeRecord.fromJson(j as Map<String, dynamic>))
          .toList();

      attendeesByEvent.clear();
      for (final r in records) {
        if (r.eventId.isNotEmpty) {
          attendeesByEvent[r.eventId] = r;
        }
      }
      notifyListeners();
    } catch (e) {
      dev.log('AttendeeService — fetchAll error: $e');
    }
  }

  void _handleChange(PostgresChangePayload payload) async {
    try {
      final newRow = payload.newRecord;
      if (newRow.isEmpty) return;

      final record = AttendeeRecord.fromJson(newRow);
      if (record.eventId.isEmpty) return;

      // Fetch event name for the activity label
      String eventName = 'Unknown Event';
      try {
        final eventData = await Supabase.instance.client
            .from('events')
            .select('eventName')
            .eq('id', record.eventId)
            .maybeSingle();
        if (eventData != null) {
          eventName = eventData['eventName'] as String? ?? 'Unknown Event';
        }
      } catch (_) {}

      // Determine what changed compared to the previous record
      final previous = attendeesByEvent[record.eventId];
      final newItems = <RecentActivityItem>[];

      if (_didFlipTrue(previous?.morningIn, record.morningIn)) {
        newItems.add(RecentActivityItem(
          eventName: eventName,
          detail: 'Morning Attendance Checked In',
          timestamp: DateTime.now(),
        ));
      }
      if (_didFlipTrue(previous?.morningOut, record.morningOut)) {
        newItems.add(RecentActivityItem(
          eventName: eventName,
          detail: 'Morning Attendance Checked Out',
          timestamp: DateTime.now(),
        ));
      }
      if (_didFlipTrue(previous?.afternoonIn, record.afternoonIn)) {
        newItems.add(RecentActivityItem(
          eventName: eventName,
          detail: 'Afternoon Attendance Checked In',
          timestamp: DateTime.now(),
        ));
      }
      if (_didFlipTrue(previous?.afternoonOut, record.afternoonOut)) {
        newItems.add(RecentActivityItem(
          eventName: eventName,
          detail: 'Afternoon Attendance Checked Out',
          timestamp: DateTime.now(),
        ));
      }

      // Update stored record
      attendeesByEvent[record.eventId] = record;

      // Prepend new activity items
      for (final item in newItems.reversed) {
        recentActivity.insert(0, item);
      }
      if (recentActivity.length > _maxRecentItems) {
        recentActivity.removeRange(_maxRecentItems, recentActivity.length);
      }

      notifyListeners();
      dev.log('AttendeeService — change handled for eventId: ${record.eventId}');
      await calculateAndSyncDues();
    } catch (e) {
      dev.log('AttendeeService — _handleChange error: $e');
    }
  }

  bool _didFlipTrue(bool? oldVal, bool newVal) {
    return newVal && (oldVal == null || oldVal == false);
  }
}
