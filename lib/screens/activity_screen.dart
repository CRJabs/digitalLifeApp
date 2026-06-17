import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/attendee_service.dart';

/// Data model representing a Supabase Event.
class SupabaseEvent {
  final String id;
  final String eventName;
  final String location;
  final String date;
  final String startTime;
  final String endTime;
  final String category;
  final bool morningIn;
  final bool morningOut;
  final bool afternoonIn;
  final bool afternoonOut;

  const SupabaseEvent({
    required this.id,
    required this.eventName,
    required this.location,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.morningIn,
    required this.morningOut,
    required this.afternoonIn,
    required this.afternoonOut,
  });

  factory SupabaseEvent.fromJson(Map<String, dynamic> json) {
    return SupabaseEvent(
      id: json['id'] as String,
      eventName: json['eventName'] as String? ?? '',
      location: json['location'] as String? ?? '',
      date: json['date'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      morningIn: json['morningIn'] as bool? ?? false,
      morningOut: json['morningOut'] as bool? ?? false,
      afternoonIn: json['afternoonIn'] as bool? ?? false,
      afternoonOut: json['afternoonOut'] as bool? ?? false,
    );
  }
}

/// Activity History screen (tab 2).
/// Shows collapsible category sections. Each expanded section lists
/// attendance events with dynamic AM and PM time-in / time-out indicator boxes.
/// Boxes show a checkmark if the current user has that boolean true in attendees.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Track which section categories are expanded
  final Map<String, bool> _expanded = {};
  List<SupabaseEvent> _events = [];
  bool _isLoading = true;
  String? _error;

  RealtimeChannel? _eventsChannel;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _subscribeToEvents();
    // Rebuild when attendee check-in state changes
    AttendeeService().addListener(_onAttendeeUpdate);
  }

  @override
  void dispose() {
    _eventsChannel?.unsubscribe();
    AttendeeService().removeListener(_onAttendeeUpdate);
    super.dispose();
  }

  void _onAttendeeUpdate() => setState(() {});

  // ── Realtime events subscription ──────────────────────────────────────────

  void _subscribeToEvents() {
    _eventsChannel = Supabase.instance.client
        .channel('events:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) => _fetchEvents(),
        )
        .subscribe();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchEvents() async {
    try {
      if (!_isLoading) {
        setState(() => _isLoading = true);
      }

      final response = await Supabase.instance.client
          .from('events')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final fetchedEvents =
          data.map((json) => SupabaseEvent.fromJson(json)).toList();

      if (!mounted) return;
      setState(() {
        _events = fetchedEvents;
        _isLoading = false;
        _error = null;

        // Auto-expand the first category on first load
        final categories = _getCategories(fetchedEvents);
        if (categories.isNotEmpty && _expanded.isEmpty) {
          _expanded[categories.first] = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> _getCategories(List<SupabaseEvent> events) {
    final unique = events.map((e) => e.category).toSet().toList();

    // Preserve a canonical ordering, then fall back to alphabetical
    final order = [
      'First Semester',
      'Second Semester',
      'UBDays 2026',
      'Other Events'
    ];
    unique.sort((a, b) {
      final indexA = order.indexOf(a);
      final indexB = order.indexOf(b);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.compareTo(b);
    });
    return unique;
  }

  void _toggle(String category) {
    setState(() => _expanded[category] = !(_expanded[category] ?? false));
  }

  String _formatDate(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[parsed.month - 1]} ${parsed.day.toString().padLeft(2, '0')}, ${parsed.year}';
    } catch (_) {
      return rawDate;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(height: mq.padding.top),

          // ── Page title ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Activity History',
              style: AppTextStyles.welcomeName.copyWith(fontSize: 18),
            ),
          ),

          // ── Loading, Error, or Accordion list ──────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.nocturnalExpedition),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load activities',
                  style: AppTextStyles.activityTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              Text(_error!,
                  style: AppTextStyles.activitySubtitle,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchEvents,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style:
                    ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_rounded,
                color: AppColors.nocturnalExpedition.withAlpha(80), size: 56),
            const SizedBox(height: 12),
            Text('No events found',
                style: AppTextStyles.activityTitle.copyWith(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchEvents,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style:
                  ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
            ),
          ],
        ),
      );
    }

    final categories = _getCategories(_events);

    return RefreshIndicator(
      onRefresh: _fetchEvents,
      color: AppColors.nocturnalExpedition,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final categoryEvents =
              _events.where((e) => e.category == category).toList();
          return _buildSection(category, categoryEvents);
        },
      ),
    );
  }

  Widget _buildSection(String category, List<SupabaseEvent> categoryEvents) {
    final isExpanded = _expanded[category] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          // ── Section header ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => _toggle(category),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.nocturnalExpedition,
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(10))
                    : BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontFamily: 'HostGrotesk',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Transform.rotate(
                    angle: isExpanded ? 0.0 : -3.14159,
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.mysticMint, width: 1),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: categoryEvents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'No events in this category',
                        style: AppTextStyles.activitySubtitle,
                      ),
                    )
                  : Column(
                      children: List.generate(categoryEvents.length, (j) {
                        final item = categoryEvents[j];
                        final isLast = j == categoryEvents.length - 1;
                        return Column(
                          children: [
                            _buildAttendanceRow(item),
                            if (!isLast)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: Color(0xFFEEF0EF),
                              ),
                          ],
                        );
                      }),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRow(SupabaseEvent item) {
    // Event booleans: whether the event has AM/PM slots at all
    final hasAm = item.morningIn || item.morningOut;
    final hasPm = item.afternoonIn || item.afternoonOut;

    // Attendee booleans: whether THIS user has checked in/out
    final attendee = AttendeeService().recordFor(item.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Event name + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.eventName, style: AppTextStyles.activityTitle),
                const SizedBox(height: 2),
                Text(
                  _formatDate(item.date),
                  style: AppTextStyles.activitySubtitle.copyWith(
                    color: AppColors.nocturnalExpedition,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // AM / PM time-in & time-out indicator boxes
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasAm)
                _buildTimePair(
                  'AM',
                  showIn: item.morningIn,
                  showOut: item.morningOut,
                  inChecked: attendee?.morningIn ?? false,
                  outChecked: attendee?.morningOut ?? false,
                ),
              if (hasAm && hasPm) const SizedBox(height: 4),
              if (hasPm)
                _buildTimePair(
                  'PM',
                  showIn: item.afternoonIn,
                  showOut: item.afternoonOut,
                  inChecked: attendee?.afternoonIn ?? false,
                  outChecked: attendee?.afternoonOut ?? false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePair(
    String label, {
    required bool showIn,
    required bool showOut,
    required bool inChecked,
    required bool outChecked,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'HostGrotesk',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A6E77),
          ),
        ),
        const SizedBox(width: 6),
        if (showIn) _TimeBox(checked: inChecked),
        if (showIn && showOut) const SizedBox(width: 4),
        if (showOut) _TimeBox(checked: outChecked),
      ],
    );
  }
}

/// A single indicator box that is empty by default and shows a checkmark
/// when [checked] is true.
class _TimeBox extends StatelessWidget {
  const _TimeBox({this.checked = false});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 34,
      height: 20,
      decoration: BoxDecoration(
        color: checked
            ? AppColors.nocturnalExpedition
            : Colors.transparent,
        border: Border.all(color: AppColors.nocturnalExpedition, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: checked
          ? const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 14,
            )
          : null,
    );
  }
}
