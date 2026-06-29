import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

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

  /// Event IDs where the student has completed both rating + written feedback.
  Set<String> completedFeedbackEventIds = {};

  /// Torchbearer points earned.
  double torchbearerPoints = 0.0;

  /// Current user's notices/announcements from administrators.
  String studentNotice = '';

  // ── Private ───────────────────────────────────────────────────────────────

  RealtimeChannel? _channel;
  RealtimeChannel? _finesNoticeChannel;
  RealtimeChannel? _eventsChannel;
  Timer? _dayCheckTimer;
  DateTime? _lastCheckedDay;
  String? _currentEmail;
  List<dynamic> _cachedEvents = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start listening for attendee changes for [email].
  /// Call this after a successful login, once the user profile is loaded.
  Future<void> startListening(String email) async {
    if (email.isEmpty) return;
    if (_currentEmail == email) return; // already listening
    _currentEmail = email;

    // Load initial records
    await _fetchAll(email);
    await _fetchCompletedFeedback(email);

    // Calculate initial dues & fetch notice
    await _fetchCachedEvents();   // must be before refreshDues
    await refreshDues();
    await _fetchTorchbearerPoints(email);
    await _fetchActiveNotice();

    // Subscribe to realtime attendee updates
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('attendees:$email')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_email',
            value: email,
          ),
          callback: (payload) => _handleChange(payload),
        )
        .subscribe();

    // Subscribe to realtime fines_notice changes
    _finesNoticeChannel?.unsubscribe();
    _finesNoticeChannel = Supabase.instance.client
        .channel('fines_notice')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fines_notice',
          callback: (_) => _fetchActiveNotice(),
        )
        .subscribe();

    // Subscribe to realtime events changes
    _eventsChannel?.unsubscribe();
    _eventsChannel = Supabase.instance.client
        .channel('events')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) async {
            dev.log('AttendeeService — events changed, refetching and recalculating dues');
            await _fetchCachedEvents();
            await refreshDues();
          },
        )
        .subscribe();

    _startDayCheckTimer();

    dev.log('AttendeeService — subscribed for email: $email');
  }

  /// Stop listening and clear state. Call on sign-out.
  Future<void> stopListening() async {
    _channel?.unsubscribe();
    _channel = null;
    _finesNoticeChannel?.unsubscribe();
    _finesNoticeChannel = null;
    _eventsChannel?.unsubscribe();
    _eventsChannel = null;
    _dayCheckTimer?.cancel();
    _dayCheckTimer = null;
    _lastCheckedDay = null;
    _currentEmail = null;
    attendeesByEvent.clear();
    recentActivity.clear();
    _cachedEvents.clear();
    outstandingDues = 0.0;
    torchbearerPoints = 0.0;
    completedFeedbackEventIds.clear();
    studentNotice = '';
    notifyListeners();
  }

  /// Returns the attendee record for a specific [eventId], or null if none.
  AttendeeRecord? recordFor(String eventId) => attendeesByEvent[eventId];

  Future<void> refreshCompletedFeedback() async {
    if (_currentEmail != null) {
      await _fetchCompletedFeedback(_currentEmail!);
      await refreshDues();
    }
  }

  Future<void> _fetchCompletedFeedback(String email) async {
    try {
      final data = await Supabase.instance.client
          .from('event_ratings')
          .select('event_id')
          .eq('student_email', email)
          .not('feedback_text', 'is', null);

      completedFeedbackEventIds = (data as List)
          .map((r) => r['event_id'].toString())
          .toSet();
      notifyListeners();
    } catch (e) {
      dev.log('AttendeeService — _fetchCompletedFeedback error: $e');
    }
  }

  Future<void> _fetchTorchbearerPoints(String email) async {
    try {
      final rows = await Supabase.instance.client
          .from('attendees')
          .select('pointsEarned')
          .ilike('student_email', email);

      double total = 0.0;
      for (final row in (rows as List)) {
        total += (row['pointsEarned'] as num?)?.toDouble() ?? 0.0;
      }
      torchbearerPoints = total;
      dev.log('AttendeeService — torchbearerPoints: $torchbearerPoints');
      notifyListeners();
    } catch (e) {
      dev.log('AttendeeService — fetchTorchbearerPoints error: $e');
    }
  }

  void _startDayCheckTimer() {
    _dayCheckTimer?.cancel();
    _lastCheckedDay = DateTime.now();
    _dayCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = DateTime.now();
      if (_lastCheckedDay == null ||
          _lastCheckedDay!.year != now.year ||
          _lastCheckedDay!.month != now.month ||
          _lastCheckedDay!.day != now.day) {
        _lastCheckedDay = now;
        dev.log('AttendeeService — calendar day changed, recalculating dues');
        refreshDues();
      }
    });
  }

  /// Computes outstanding dues from the in-memory getMissingChecks() result
  /// and notifies listeners. This is always accurate regardless of whether
  /// the attendees.student_email column has been backfilled.
  void _recomputeDues() {
    outstandingDues = getMissingChecks()
        .fold(0.0, (sum, item) => sum + item.totalFine);
    dev.log('AttendeeService — recomputeDues: ₱$outstandingDues');
    notifyListeners();
  }

  /// Refreshes outstanding dues. Recomputes from in-memory state, then
  /// syncs with the server-side view.
  Future<void> refreshDues() async {
    _recomputeDues();
    // Sync with server view if student_email is set
    if (_currentEmail == null || _currentEmail!.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('student_fines_view')
          .select('outstanding_dues')
          .eq('student_email', _currentEmail!)
          .maybeSingle();
      final viewDues = (row?['outstanding_dues'] as num?)?.toDouble();
      if (viewDues != null) {
        if (viewDues > outstandingDues) {
          final diff = viewDues - outstandingDues;
          NotificationService.showLocalNotification(
            'New Fine Added 🔴',
            'A fine of ₱${diff.toStringAsFixed(2)} has been added to your account.',
          );
        }
        outstandingDues = viewDues;
        dev.log('AttendeeService — refreshDues: updated outstandingDues from server view to ₱$outstandingDues');
        notifyListeners();
      }
    } catch (e) {
      dev.log('AttendeeService — refreshDues view check error: $e');
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
        final hasFeedback = completedFeedbackEventIds.contains(eventId);
        list.add(MissingCheckInfo(
          eventName: eventName,
          date: eventDateStr,
          missingSlots: missingSlots,
          totalFine: hasFeedback ? 0.0 : missingSlots.length * 25.0,
        ));
      }
    }
    return list;
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<void> _fetchAll(String email) async {
    try {
      final data = await Supabase.instance.client
          .from('attendees')
          .select()
          .ilike('student_email', email);

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

  /// Fetches and caches the full events list for getMissingChecks().
  Future<void> _fetchCachedEvents() async {
    try {
      final eventsData = await Supabase.instance.client
          .from('events')
          .select()
          .order('created_at', ascending: false);
      _cachedEvents = eventsData as List<dynamic>;
    } catch (e) {
      dev.log('AttendeeService — _fetchCachedEvents error: $e');
    }
  }

  /// Fetches the active admin notice from fines_notice.
  Future<void> _fetchActiveNotice() async {
    try {
      final row = await Supabase.instance.client
          .from('fines_notice')
          .select('content')
          .eq('is_active', true)
          .maybeSingle();
      final newNotice = row?['content'] as String? ?? '';
      if (newNotice.isNotEmpty && newNotice != studentNotice) {
        NotificationService.showLocalNotification(
          'New Notice from Admin 📋',
          newNotice.length > 80 ? '${newNotice.substring(0, 80)}...' : newNotice,
        );
      }
      studentNotice = newNotice;
      notifyListeners();
    } catch (e) {
      dev.log('AttendeeService — _fetchActiveNotice error: $e');
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
        NotificationService.showLocalNotification(
          'Morning Check-in Confirmed ✅',
          'Your morning check-in for $eventName has been recorded.',
        );
      }
      if (_didFlipTrue(previous?.morningOut, record.morningOut)) {
        newItems.add(RecentActivityItem(
          eventName: eventName,
          detail: 'Morning Attendance Checked Out',
          timestamp: DateTime.now(),
        ));
        NotificationService.showLocalNotification(
          'Morning Check-out Confirmed ✅',
          'Your morning check-out for $eventName has been recorded.',
        );
      }
      if (_didFlipTrue(previous?.afternoonIn, record.afternoonIn)) {
        newItems.add(RecentActivityItem(
          eventName: eventName,
          detail: 'Afternoon Attendance Checked In',
          timestamp: DateTime.now(),
        ));
        NotificationService.showLocalNotification(
          'Afternoon Check-in Confirmed ✅',
          'Your afternoon check-in for $eventName has been recorded.',
        );
      }
      if (_didFlipTrue(previous?.afternoonOut, record.afternoonOut)) {
        newItems.add(RecentActivityItem(
          eventName: eventName,
          detail: 'Afternoon Attendance Checked Out',
          timestamp: DateTime.now(),
        ));
        NotificationService.showLocalNotification(
          'Afternoon Check-out Confirmed ✅',
          'Your afternoon check-out for $eventName has been recorded.',
        );
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

      if (_currentEmail != null) {
        await _fetchCompletedFeedback(_currentEmail!);
        await _fetchTorchbearerPoints(_currentEmail!);
      }
      notifyListeners();
      dev.log('AttendeeService — change handled for eventId: ${record.eventId}');
      await refreshDues();
    } catch (e) {
      dev.log('AttendeeService — _handleChange error: $e');
    }
  }

  bool _didFlipTrue(bool? oldVal, bool newVal) {
    return newVal && (oldVal == null || oldVal == false);
  }
}
