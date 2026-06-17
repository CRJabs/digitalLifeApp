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

/// Singleton that subscribes to Supabase realtime updates on the `attendees`
/// table for the currently logged-in user (matched by name), and notifies
/// listeners so both [HomeScreen] and [ActivityScreen] stay in sync.
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

  // ── Private ───────────────────────────────────────────────────────────────

  RealtimeChannel? _channel;
  String? _currentUserName;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start listening for attendee changes for [userName].
  /// Call this after a successful login, once the user profile is loaded.
  Future<void> startListening(String userName) async {
    if (userName.isEmpty) return;
    if (_currentUserName == userName) return; // already listening
    _currentUserName = userName;

    // Load initial records
    await _fetchAll(userName);

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
    dev.log('AttendeeService — subscribed for user: $userName');
  }

  /// Stop listening and clear state. Call on sign-out.
  Future<void> stopListening() async {
    _channel?.unsubscribe();
    _channel = null;
    _currentUserName = null;
    attendeesByEvent.clear();
    recentActivity.clear();
    notifyListeners();
  }

  /// Returns the attendee record for a specific [eventId], or null if none.
  AttendeeRecord? recordFor(String eventId) => attendeesByEvent[eventId];

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
  }

  bool _didFlipTrue(bool? oldVal, bool newVal) {
    return newVal && (oldVal == null || oldVal == false);
  }
}
