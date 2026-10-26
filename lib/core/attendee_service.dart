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
  final bool isCompulsory;
  final bool providePoints;
  final int pointsAwarded;

  MissingCheckInfo({
    required this.eventName,
    required this.date,
    required this.missingSlots,
    required this.totalFine,
    required this.isCompulsory,
    required this.providePoints,
    required this.pointsAwarded,
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
  StreamSubscription<AuthState>? _authSub;
  List<MissingCheckInfo>? _cachedMissingChecks;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start listening for attendee changes for [email].
  /// Call this after a successful login, once the user profile is loaded.
  Future<void> startListening(String email) async {
    if (email.isEmpty) return;
    if (_currentEmail == email) return; // already listening
    _currentEmail = email;
    _cachedMissingChecks = null;

    // Listen for auth state transitions to resubscribe or clear automatically
    _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (data.event == AuthChangeEvent.signedOut) {
        stopListening();
      } else if (session?.user.email != null &&
          session!.user.email!.isNotEmpty &&
          session.user.email != _currentEmail) {
        startListening(session.user.email!);
      }
    });

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
            _cachedMissingChecks = null;
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
    _authSub?.cancel();
    _authSub = null;
    _cachedMissingChecks = null;
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
      await _fetchTorchbearerPoints(_currentEmail!);
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
      // 1. Primary: sync from student_fines_view where total_points is accurately
      // calculated by recalculate_student_fines based on attended AND rated events.
      final row = await Supabase.instance.client
          .from('student_fines_view')
          .select('total_points')
          .ilike('student_email', email)
          .maybeSingle();

      if (row != null && row['total_points'] != null) {
        torchbearerPoints = (row['total_points'] as num).toDouble();
        dev.log('AttendeeService — torchbearerPoints (from view): $torchbearerPoints');
        notifyListeners();
        return;
      }

      // 2. Fallback: calculate directly for rated events where all configured sessions are attended
      double total = 0.0;
      for (final eventJson in _cachedEvents) {
        final eventId = eventJson['id'] as String;
        final providePoints = eventJson['providePoints'] as bool? ?? false;
        if (!providePoints) continue;

        // User MUST have completed rating/feedback for this event
        if (!completedFeedbackEventIds.contains(eventId)) continue;

        final attendee = recordFor(eventId);
        if (attendee == null) continue;

        final morningInReq = eventJson['morningIn'] as bool? ?? false;
        final morningOutReq = eventJson['morningOut'] as bool? ?? false;
        final afternoonInReq = eventJson['afternoonIn'] as bool? ?? false;
        final afternoonOutReq = eventJson['afternoonOut'] as bool? ?? false;

        final hasAny = morningInReq || morningOutReq || afternoonInReq || afternoonOutReq;
        if (!hasAny) continue;

        if (morningInReq && !attendee.morningIn) continue;
        if (morningOutReq && !attendee.morningOut) continue;
        if (afternoonInReq && !attendee.afternoonIn) continue;
        if (afternoonOutReq && !attendee.afternoonOut) continue;

        final pts = (eventJson['pointsAwarded'] as num?)?.toDouble() ?? 0.0;
        total += pts;
      }
      torchbearerPoints = total;
      dev.log('AttendeeService — torchbearerPoints (fallback): $torchbearerPoints');
      notifyListeners();
    } catch (e) {
      dev.log('AttendeeService — fetchTorchbearerPoints error: $e');
    }
  }

  void _startDayCheckTimer() {
    _dayCheckTimer?.cancel();
    _lastCheckedDay = DateTime.now();
    _dayCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final now = DateTime.now();
      if (_lastCheckedDay == null ||
          _lastCheckedDay!.year != now.year ||
          _lastCheckedDay!.month != now.month ||
          _lastCheckedDay!.day != now.day) {
        _lastCheckedDay = now;
        _cachedMissingChecks = null;
        dev.log('AttendeeService — calendar day changed, recalculating dues');
        refreshDues();
      } else {
        _recomputeDues();
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
        // Ensure server view doesn't exceed accurate client dues for today/past events
        final localDues = getMissingChecks().fold(0.0, (sum, item) => sum + item.totalFine);
        final syncedDues = viewDues > localDues ? localDues : viewDues;
        outstandingDues = syncedDues;
        dev.log('AttendeeService — refreshDues: updated outstandingDues to ₱$outstandingDues');
        notifyListeners();
      }
    } catch (e) {
      dev.log('AttendeeService — refreshDues view check error: $e');
    }
  }

  /// Parses 12-hour (e.g. "3:00 PM", "08:30 AM") or 24-hour (e.g. "15:00") time strings
  /// on a given [eventDate].
  DateTime? _parseSlotDateTime(DateTime eventDate, String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final clean = timeStr.trim().toUpperCase();

    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');

    final digitsAndColons = clean.replaceAll(RegExp(r'[^\d:]'), '');
    final parts = digitsAndColons.split(':');
    if (parts.isEmpty || parts[0].isEmpty) return null;

    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return DateTime(eventDate.year, eventDate.month, eventDate.day, hour, minute, second);
  }

  /// Determines whether a specific slot's scheduled attendance time has passed.
  bool _hasSlotPassed({
    required bool isToday,
    required DateTime now,
    required DateTime eventDate,
    required String? slotTime,
    required String? fallbackTime,
    required int defaultHour,
    required int defaultMinute,
  }) {
    if (!isToday) {
      // Past event: the date is already before today, so all slots have passed.
      return true;
    }
    final parsed = _parseSlotDateTime(eventDate, slotTime) ??
        _parseSlotDateTime(eventDate, fallbackTime) ??
        DateTime(eventDate.year, eventDate.month, eventDate.day, defaultHour, defaultMinute);

    return now.isAfter(parsed);
  }

  /// Compiles details of all missing checks for events that are today or in the past.
  /// For events occurring today, checks are only marked as missed if their scheduled
  /// cutoff time has actually passed.
  List<MissingCheckInfo> getMissingChecks({bool forceRefresh = false}) {
    if (!forceRefresh && _cachedMissingChecks != null) {
      return _cachedMissingChecks!;
    }
    final list = <MissingCheckInfo>[];
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    for (final eventJson in _cachedEvents) {
      final eventId = eventJson['id'] as String;
      final eventName = eventJson['eventName'] as String? ?? 'Unknown Event';
      final eventDateStr = eventJson['date'] as String? ?? '';
      final isVoid = eventJson['isVoid'] as bool? ?? eventJson['is_void'] as bool? ?? false;
      if (isVoid) continue;

      DateTime? eventDate;
      try {
        eventDate = DateTime.parse(eventDateStr);
      } catch (_) {}

      if (eventDate == null) continue;

      final eventCompareDate = DateTime(eventDate.year, eventDate.month, eventDate.day);
      if (eventCompareDate.isAfter(todayDate)) {
        continue;
      }

      final isToday = eventCompareDate.isAtSameMomentAs(todayDate);

      final morningInReq = eventJson['morningIn'] as bool? ?? false;
      final morningOutReq = eventJson['morningOut'] as bool? ?? false;
      final afternoonInReq = eventJson['afternoonIn'] as bool? ?? false;
      final afternoonOutReq = eventJson['afternoonOut'] as bool? ?? false;

      final startTime = eventJson['startTime'] as String?;
      final endTime = eventJson['endTime'] as String?;
      final morningInTime = eventJson['morningInTime'] as String?;
      final morningOutTime = eventJson['morningOutTime'] as String?;
      final afternoonInTime = eventJson['afternoonInTime'] as String?;
      final afternoonOutTime = eventJson['afternoonOutTime'] as String?;

      final attendee = recordFor(eventId);
      final isCompulsory = eventJson['isCompulsory'] as bool? ?? false;
      final isRated = completedFeedbackEventIds.contains(eventId);
      final missingSlots = <String>[];

      if (morningInReq) {
        if (attendee == null || !attendee.morningIn) {
          if (_hasSlotPassed(
            isToday: isToday,
            now: now,
            eventDate: eventCompareDate,
            slotTime: morningInTime,
            fallbackTime: startTime,
            defaultHour: 12,
            defaultMinute: 0,
          )) {
            missingSlots.add('Morning Check-in');
          }
        } else if (isCompulsory && !isRated) {
          missingSlots.add('Morning Check-in (Pending Rating)');
        }
      }

      if (morningOutReq) {
        if (attendee == null || !attendee.morningOut) {
          if (_hasSlotPassed(
            isToday: isToday,
            now: now,
            eventDate: eventCompareDate,
            slotTime: morningOutTime,
            fallbackTime: startTime,
            defaultHour: 12,
            defaultMinute: 0,
          )) {
            missingSlots.add('Morning Check-out');
          }
        } else if (isCompulsory && !isRated) {
          missingSlots.add('Morning Check-out (Pending Rating)');
        }
      }

      if (afternoonInReq) {
        if (attendee == null || !attendee.afternoonIn) {
          if (_hasSlotPassed(
            isToday: isToday,
            now: now,
            eventDate: eventCompareDate,
            slotTime: afternoonInTime,
            fallbackTime: startTime,
            defaultHour: 13,
            defaultMinute: 0,
          )) {
            missingSlots.add('Afternoon Check-in');
          }
        } else if (isCompulsory && !isRated) {
          missingSlots.add('Afternoon Check-in (Pending Rating)');
        }
      }

      if (afternoonOutReq) {
        if (attendee == null || !attendee.afternoonOut) {
          if (_hasSlotPassed(
            isToday: isToday,
            now: now,
            eventDate: eventCompareDate,
            slotTime: afternoonOutTime,
            fallbackTime: endTime,
            defaultHour: 17,
            defaultMinute: 0,
          )) {
            missingSlots.add('Afternoon Check-out');
          }
        } else if (isCompulsory && !isRated) {
          missingSlots.add('Afternoon Check-out (Pending Rating)');
        }
      }

      if (missingSlots.isNotEmpty) {
        final isCompulsory = eventJson['isCompulsory'] as bool? ?? false;
        final providePoints = eventJson['providePoints'] as bool? ?? false;
        
        int parsePoints(dynamic val) {
          if (val == null) return 0;
          if (val is num) return val.toInt();
          if (val is String) return int.tryParse(val) ?? double.tryParse(val)?.toInt() ?? 0;
          return 0;
        }
        final pointsAwarded = parsePoints(eventJson['pointsAwarded']);

        // Only count actual missed check-ins for the monetary fine; do NOT fine for attended events pending rating
        final actualMissedCount = missingSlots.where((s) => !s.contains('Pending Rating')).length;

        list.add(MissingCheckInfo(
          eventName: eventName,
          date: eventDateStr,
          missingSlots: missingSlots,
          totalFine: isCompulsory ? (actualMissedCount * 50.0) : 0.0,
          isCompulsory: isCompulsory,
          providePoints: providePoints,
          pointsAwarded: pointsAwarded,
        ));
      }
    }
    _cachedMissingChecks = list;
    return list;
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<void> _fetchAll(String email) async {
    try {
      final data = await Supabase.instance.client
          .from('attendees')
          .select('id, eventId, name, morningIn, morningOut, afternoonIn, afternoonOut, created_at, student_email')
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
      _cachedMissingChecks = null;
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
          .select('id, eventName, date, morningIn, morningOut, afternoonIn, afternoonOut, isCompulsory, isVoid, providePoints, pointsAwarded, morningInTime, morningOutTime, afternoonInTime, afternoonOutTime')
          .order('created_at', ascending: false);
      _cachedEvents = eventsData as List<dynamic>;
      _cachedMissingChecks = null;
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

      // Fetch event name from cache first, avoiding N+1 DB query
      String eventName = 'Unknown Event';
      try {
        final cached = _cachedEvents.firstWhere(
          (e) => (e['id'] as String?) == record.eventId,
          orElse: () => null,
        );
        if (cached != null) {
          eventName = cached['eventName'] as String? ?? 'Unknown Event';
        } else {
          final eventData = await Supabase.instance.client
              .from('events')
              .select('eventName')
              .eq('id', record.eventId)
              .maybeSingle();
          if (eventData != null) {
            eventName = eventData['eventName'] as String? ?? 'Unknown Event';
          }
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
      _cachedMissingChecks = null;

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
