import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_date_utils.dart';
import '../core/app_text_styles.dart';
import '../core/attendee_service.dart';
import '../core/user_profile_service.dart';

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
  const ActivityScreen({super.key, this.isActive = false});
  final bool isActive;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Track which section categories are expanded
  final Map<String, bool> _expanded = {};
  List<SupabaseEvent> _events = [];
  Set<String> _ratedEventIds = {};
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
  void didUpdateWidget(covariant ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _expandAllCategories();
    }
  }

  void _expandAllCategories() {
    setState(() {
      final categories = _getCategories(_events);
      for (final category in categories) {
        _expanded[category] = true;
      }
    });
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
      final fetchedEvents = data
          .map((json) => SupabaseEvent.fromJson(json))
          .toList();

      // Fetch student's ratings to know which events they've rated
      final userName = UserProfileService().name;
      Set<String> ratedIds = {};
      try {
        final ratingsData = await Supabase.instance.client
            .from('event_ratings')
            .select('event_id')
            .eq('student_name', userName);

        final List<dynamic> ratingsList = ratingsData as List<dynamic>;
        ratedIds = ratingsList.map((r) => r['event_id'].toString()).toSet();
      } catch (_) {
        // If table doesn't exist yet, default to empty set
      }

      if (!mounted) return;
      setState(() {
        _events = fetchedEvents;
        _ratedEventIds = ratedIds;
        _isLoading = false;
        _error = null;

        // Auto-expand all categories on load
        final categories = _getCategories(fetchedEvents);
        for (final category in categories) {
          _expanded[category] = true;
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
      'Other Events',
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


  DateTime? _parseFallbackDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        final cleaned = dateStr.replaceAll(',', '');
        final parts = cleaned.split(' ');
        if (parts.length == 3) {
          final monthStr = parts[0];
          final dayStr = parts[1];
          final yearStr = parts[2];

          const months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          final monthIndex = months.indexOf(monthStr);
          if (monthIndex != -1) {
            final month = monthIndex + 1;
            final day = int.parse(dayStr);
            final year = int.parse(yearStr);
            return DateTime(year, month, day);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  bool _isEventFinished(SupabaseEvent event) {
    try {
      final datePart = _parseFallbackDate(event.date);
      if (datePart == null) return false;

      final timeParts = event.endTime.split(':');
      if (timeParts.length >= 2) {
        int hour = int.parse(timeParts[0].trim());
        final minutePart = timeParts[1].toLowerCase();
        int minute = int.parse(RegExp(r'\d+').stringMatch(minutePart) ?? '0');
        if (minutePart.contains('pm') && hour < 12) {
          hour += 12;
        } else if (minutePart.contains('am') && hour == 12) {
          hour = 0;
        }
        final eventEnd = DateTime(
          datePart.year,
          datePart.month,
          datePart.day,
          hour,
          minute,
        );
        return DateTime.now().isAfter(eventEnd);
      }
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final compareDate = DateTime(datePart.year, datePart.month, datePart.day);
      return todayDate.isAfter(compareDate) ||
          todayDate.isAtSameMomentAs(compareDate);
    } catch (_) {
      return false;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, mq.padding.top + 20, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'Activity History',
                        style: AppTextStyles.welcomeName,
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/lifeColored.png',
                  height: 38,
                  fit: BoxFit.contain,
                ),
              ],
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
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load activities',
                style: AppTextStyles.activityTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: AppTextStyles.activitySubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchEvents,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(140, 44),
                ),
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
            Icon(
              Icons.event_note_rounded,
              color: AppColors.nocturnalExpedition.withAlpha(80),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'No events found',
              style: AppTextStyles.activityTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchEvents,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final categoryEvents = _events
              .where((e) => e.category == category)
              .toList();
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                      fontFamily: 'Figtree',
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

    final isFinished = _isEventFinished(item);
    final datePart = _parseFallbackDate(item.date);
    final isToday = datePart != null &&
        DateTime.now().year == datePart.year &&
        DateTime.now().month == datePart.month &&
        DateTime.now().day == datePart.day;
    final hasCheck =
        attendee != null &&
        (attendee.morningIn ||
            attendee.morningOut ||
            attendee.afternoonIn ||
            attendee.afternoonOut);
    final hasRated = _ratedEventIds.contains(item.id);
    final showRateButton = (isFinished || isToday) && hasCheck && !hasRated;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      AppDateUtils.formatDate(item.date),
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
          if (showRateButton) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showRatingModal(item),
                icon: const Icon(
                  Icons.star_border_rounded,
                  size: 16,
                  color: AppColors.oceanicNoir,
                ),
                label: const Text(
                  'Rate this event!',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.oceanicNoir,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: AppColors.mysticMint.withAlpha(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(
                      color: AppColors.mysticMint,
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRatingModal(SupabaseEvent event) {
    final userName = UserProfileService().name;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        int selectedRating = 0;
        bool isLoading = true;
        bool isSubmitting = false;
        String? modalError;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Fetch initial rating once
            if (isLoading && modalError == null) {
              Future.microtask(() async {
                try {
                  final data = await Supabase.instance.client
                      .from('event_ratings')
                      .select('rating')
                      .eq('event_id', event.id)
                      .eq('student_name', userName)
                      .maybeSingle();

                  if (!context.mounted) return;
                  setModalState(() {
                    if (data != null && data['rating'] != null) {
                      selectedRating = data['rating'] as int;
                    }
                    isLoading = false;
                  });
                } catch (e) {
                  if (!context.mounted) return;
                  setModalState(() {
                    isLoading = false;
                  });
                }
              });
            }

            final ratingLabels = [
              'Select rating',
              'Poor',
              'Fair',
              'Good',
              'Very Good',
              'Excellent',
            ];

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Rate Event',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.oceanicNoir,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: AppColors.nocturnalExpedition.withAlpha(120),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How would you rate your experience at "${event.eventName}"?',
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF5A6E77),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (isLoading)
                      const SizedBox(
                        height: 60,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.oceanicNoir,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starRating = index + 1;
                          final isStarred = starRating <= selectedRating;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedRating = starRating;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                isStarred
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 40,
                                color: isStarred
                                    ? Colors.amber.shade600
                                    : AppColors.mysticMint,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          ratingLabels[selectedRating],
                          key: ValueKey(selectedRating),
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selectedRating > 0
                                ? AppColors.oceanicNoir
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.mysticMint,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.nocturnalExpedition,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (selectedRating == 0 || isSubmitting)
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        isSubmitting = true;
                                      });
                                      try {
                                        await Supabase.instance.client
                                            .from('event_ratings')
                                            .upsert({
                                              'event_id': event.id,
                                              'student_name': userName,
                                              'rating': selectedRating,
                                            });

                                        if (!mounted) return;
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                        setState(() {
                                          _ratedEventIds.add(event.id);
                                        });
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Thank you for your feedback!',
                                              style: const TextStyle(
                                                fontFamily: 'Figtree',
                                                fontSize: 13,
                                              ),
                                            ),
                                            backgroundColor:
                                                AppColors.oceanicNoir,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        setModalState(() {
                                          isSubmitting = false;
                                          modalError =
                                              'Failed to submit rating: $e';
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.oceanicNoir,
                                disabledBackgroundColor: AppColors.oceanicNoir
                                    .withAlpha(80),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontFamily: 'Figtree',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (modalError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          modalError!,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 11,
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
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
            fontFamily: 'Figtree',
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
        color: checked ? AppColors.nocturnalExpedition : Colors.transparent,
        border: Border.all(color: AppColors.nocturnalExpedition, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }
}
