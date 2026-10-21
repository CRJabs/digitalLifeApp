import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/attendee_service.dart';
import '../core/user_profile_service.dart';

/// Home / main screen (tab 0).
/// Shows a welcome header, the "View QR Code" action card, and a
/// Recent Activity list sourced from live Supabase attendee updates.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onViewQrTap, this.onSeeAllTap});

  /// Called when the user taps the "View QR Code" card; used by [MainShell]
  /// to switch to the Scanner tab.
  final VoidCallback? onViewQrTap;

  /// Called when the user taps "See all" on Recent Activity.
  final VoidCallback? onSeeAllTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _carouselController;
  Timer? _carouselTimer;
  int _carouselPage = 0;
  List<Map<String, String>> _dbCarouselItems = [];

  final PageController _dualCardController = PageController();
  int _dualCardPage = 0;

  // ── Today's events card ──────────────────────────────────────────────────
  final PageController _todayEventsController = PageController();
  List<Map<String, dynamic>> _todayEvents = [];
  bool _todayEventsLoading = true;

  final List<Map<String, String>> _placeholderCarouselItems = [
    {
      'title': 'Sports Fest 2026',
      'desc': 'UBDays Sports Fest starts Wednesday! Settle your dues to receive your gate entry pass.',
      'image_url': '',
      'overlay_color': '',
      'overlay_opacity': '0.0',
      'text_color': '',
      'border_color': '',
    },
    {
      'title': 'Midterm Examinations',
      'desc': 'Midterms are scheduled for July 6-10. Double check your missing attendance check-ins.',
      'image_url': '',
      'overlay_color': '',
      'overlay_opacity': '0.0',
      'text_color': '',
      'border_color': '',
    },
    {
      'title': 'App Feedback',
      'desc': 'We want to hear from you! Share your thoughts about the new LiFe app in our online survey.',
      'image_url': '',
      'overlay_color': '',
      'overlay_opacity': '0.0',
      'text_color': '',
      'border_color': '',
    },
  ];

  List<Map<String, String>> get _activeCarouselItems =>
      _dbCarouselItems.isNotEmpty ? _dbCarouselItems : _placeholderCarouselItems;

  RealtimeChannel? _carouselChannel;

  RealtimeChannel? _eventsChannel;

  @override
  void initState() {
    super.initState();
    AttendeeService().addListener(_onAttendeeUpdate);
    UserProfileService().addListener(_onProfileUpdate);
    _carouselController = PageController(initialPage: 0);
    _fetchCarouselItems();
    _subscribeToCarousel();
    _subscribeToEvents();
    _startCarouselTimer();
    _fetchTodaysEvents();
  }

  @override
  void dispose() {
    _carouselChannel?.unsubscribe();
    _eventsChannel?.unsubscribe();
    _carouselTimer?.cancel();
    _carouselController.dispose();
    _dualCardController.dispose();
    _todayEventsController.dispose();
    AttendeeService().removeListener(_onAttendeeUpdate);
    UserProfileService().removeListener(_onProfileUpdate);
    super.dispose();
  }

  void _subscribeToCarousel() {
    _carouselChannel = Supabase.instance.client
        .channel('carousel:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'carousel_items',
          callback: (_) => _fetchCarouselItems(),
        )
        .subscribe();
  }

  void _subscribeToEvents() {
    _eventsChannel = Supabase.instance.client
        .channel('events:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) => _fetchTodaysEvents(),
        )
        .subscribe();
  }

  void _onAttendeeUpdate() => setState(() {});
  void _onProfileUpdate() => setState(() {});

  Future<void> _fetchCarouselItems() async {
    try {
      final data = await Supabase.instance.client
          .from('carousel_items')
          .select()
          .order('created_at', ascending: false);
      if (data.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _dbCarouselItems = data.map((item) {
            return {
              'title': item['title'] as String? ?? '',
              'desc': item['description'] as String? ?? '',
              'image_url': item['image_url'] as String? ?? '',
              'overlay_image_url': item['overlay_image_url'] as String? ?? '',
              'overlay_color': item['overlay_color'] as String? ?? '',
              'overlay_opacity': (item['overlay_opacity'] ?? 0.0).toString(),
              'text_color': item['text_color'] as String? ?? '',
              'border_color': item['border_color'] as String? ?? '',
            };
          }).toList();
        });
      }
    } catch (_) {
      // Gracefully fall back to local placeholders on network/db error
    }
  }

  Future<void> _fetchTodaysEvents() async {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final data = await Supabase.instance.client
          .from('events')
          .select(
              'id, eventName, location, startTime, endTime, morningIn, morningOut, afternoonIn, afternoonOut, morningInTime, morningOutTime, afternoonInTime, afternoonOutTime, isCompulsory, providePoints, pointsAwarded')
          .eq('date', todayStr)
          .order('startTime', ascending: true);
      if (!mounted) return;
      setState(() {
        _todayEvents = List<Map<String, dynamic>>.from(data);
        _todayEventsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _todayEventsLoading = false);
    }
  }

  Color? _parseHexColor(String hexStr) {
    try {
      var hex = hexStr.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted) return;
      final items = _activeCarouselItems;
      if (items.isEmpty) return;
      _carouselPage = (_carouselPage + 1) % items.length;
      _carouselController.animateToPage(
        _carouselPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }



  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final profile = UserProfileService();

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // ── Main scrollable body ─────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              _buildHeader(mq, profile),

              // ── Scrollable body ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 304.0 + mq.padding.bottom), // Large bottom padding to scroll past floating carousel + navbar
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDualInfoCard(),
                      _buildTodayEventsCard(),
                      const SizedBox(height: 28),
                      _buildSectionHeader(),
                      const SizedBox(height: 12),
                      _buildActivityList(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Fade background for navbar + carousel backing ───────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 282,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.white,
                      Colors.white,
                      Colors.white.withAlpha(200),
                      Colors.white.withAlpha(0),
                    ],
                    stops: const [0.0, 0.8, 0.9, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Floating carousel above navbar ───────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: _buildFloatingCarousel(),
          ),
        ],
      ),
    );
  }

  // ── Outstanding Dues / Points card ──────────────────────────────────────
  Widget _buildDualInfoCard() {
    final dues = AttendeeService().outstandingDues;
    final points = AttendeeService().torchbearerPoints;

    return Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mysticMint, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _dualCardController,
                onPageChanged: (p) => setState(() => _dualCardPage = p),
                children: [
                  // Page 1: Outstanding Fines
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.oceanicNoir.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: AppColors.oceanicNoir,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Outstanding Fines',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF5A6E77),
                                ),
                              ),
                              Text(
                                '₱${dues.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.oceanicNoir,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (dues > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Pending',
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade700,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Cleared',
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Page 2: Torchbearer Points
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.amber.shade700,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Torchbearer Points',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF5A6E77),
                                ),
                              ),
                              Text(
                                '${points.toStringAsFixed(0)} ${points.toInt() == 1 ? 'pt' : 'pts'}',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            points > 0 ? 'Earned' : 'None yet',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Page indicator dots
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  2,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: _dualCardPage == i ? 12 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _dualCardPage == i
                          ? AppColors.nocturnalExpedition
                          : AppColors.mysticMint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(MediaQueryData mq, UserProfileService profile) {
    final parts = profile.name.trim().split(' ');
    final displayName =
        parts.length > 1 ? '${parts[0]} ${parts[1]}' : profile.name;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, mq.padding.top + 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome Back!', style: AppTextStyles.welcomeLabel),
                const SizedBox(height: 2),
                Text('$displayName!', style: AppTextStyles.welcomeName),
              ],
            ),
          ),
          Image.asset('assets/lifeColored.png', height: 38, fit: BoxFit.contain),
        ],
      ),
    );
  }

  // ── Today's Events card ───────────────────────────────────────────────────
  Widget _buildTodayEventsCard() {
    // Loading state
    if (_todayEventsLoading) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.nocturnalExpedition,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.nocturnalExpedition.withAlpha(70),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Filter: show events that haven't ended yet (both upcoming and currently ongoing).
    // Only fully past events (endTime < now) are hidden.
    TimeOfDay parseHHMM(String s) {
      final parts = s.split(':');
      if (parts.length < 2) return const TimeOfDay(hour: 0, minute: 0);
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;

    final todayActiveEvents = _todayEvents.where((ev) {
      final end = parseHHMM(ev['endTime'] as String? ?? '');
      final endMins = end.hour * 60 + end.minute;
      return nowMins <= endMins; // upcoming or ongoing; exclude only ended events
    }).toList();

    // No active events today — fall back to the QR code card
    if (todayActiveEvents.isEmpty) {
      return _buildQrCodeCard();
    }

    // One or more active events today — PageView
    final totalPages = todayActiveEvents.length;
    return SizedBox(
      height: 122,
      child: PageView.builder(
        controller: _todayEventsController,
        itemCount: totalPages,
        itemBuilder: (context, i) {
          final ev = todayActiveEvents[i];
          final name = ev['eventName'] as String? ?? '';
          final location = ev['location'] as String? ?? '';
          final startTime = ev['startTime'] as String? ?? '';
          final endTime = ev['endTime'] as String? ?? '';
          final isCompulsory = ev['isCompulsory'] as bool? ?? false;
          final providePoints = ev['providePoints'] as bool? ?? false;
          final pointsAwarded = (ev['pointsAwarded'] as num?)?.toInt() ?? 0;

          // Build check-in window text from individual slot times
          final morningIn = ev['morningIn'] as bool? ?? false;
          final morningOut = ev['morningOut'] as bool? ?? false;
          final afternoonIn = ev['afternoonIn'] as bool? ?? false;
          final afternoonOut = ev['afternoonOut'] as bool? ?? false;

          final slots = <String>[];
          if (morningIn || morningOut) slots.add('Morning');
          if (afternoonIn || afternoonOut) slots.add('Afternoon');
          final sessionText = slots.isEmpty ? '' : slots.join(' & ');

          return Padding(
            padding: EdgeInsets.only(
              right: i < totalPages - 1 ? 12 : 0,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.nocturnalExpedition, AppColors.oceanicNoir],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.nocturnalExpedition.withAlpha(70),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onViewQrTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Top row: icon + event name + page dots
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(22),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.today_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Label row: "Today's Event" + badges inline
                                  Row(
                                    children: [
                                      const Text(
                                        'Today\'s Event',
                                        style: TextStyle(
                                          fontFamily: 'Figtree',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFAEC8CC),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isCompulsory)
                                        _smallBadge('Compulsory', Colors.red.shade300, Colors.red.withAlpha(50))
                                      else
                                        _smallBadge('Voluntary', Colors.grey.shade400, Colors.grey.withAlpha(40)),
                                      if (providePoints && pointsAwarded > 0) ...[  
                                        const SizedBox(width: 4),
                                        _smallBadge('+$pointsAwarded ${pointsAwarded == 1 ? 'pt' : 'pts'}', Colors.amber.shade300, Colors.amber.withAlpha(50)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Page indicator dots
                            if (totalPages > 1)
                              Row(
                                children: List.generate(totalPages, (dot) {
                                  return Container(
                                    width: dot == i ? 16 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: dot == i
                                          ? Colors.white
                                          : Colors.white.withAlpha(60),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Bottom row: location chip + time chip + badges (auto-scrolling and contained within card)
                        _AutoScrollingChips(
                          spacing: 8,
                          children: [
                            // Location
                            _chip(
                              Icons.location_on_rounded,
                              location.isNotEmpty ? location : 'TBA',
                            ),
                            // Time
                            _chip(
                              Icons.access_time_rounded,
                              '${_format24to12(startTime)} – ${_format24to12(endTime)}',
                            ),
                            // Session slots
                            if (sessionText.isNotEmpty)
                              _chip(Icons.wb_sunny_rounded, sessionText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQrCodeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.nocturnalExpedition,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.nocturnalExpedition.withAlpha(70),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onViewQrTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View QR Code',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Check your attendance',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFAEC8CC),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallBadge(String label, Color borderColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: const Color(0xFFAEC8CC)),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFFAEC8CC),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────────────────
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Recent Activity', style: AppTextStyles.sectionTitle),
        GestureDetector(
          onTap: widget.onSeeAllTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('See all', style: AppTextStyles.seeAll),
          ),
        ),
      ],
    );
  }

  // ── Floating Carousel ────────────────────────────────────────────────────
  Widget _buildFloatingCarousel() {
    final items = _activeCarouselItems;
    if (items.isEmpty) return const SizedBox.shrink();

    // Custom carousel height
    const double carouselHeight = 154.0;

    return Container(
      height: carouselHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mysticMint, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // PageView fills the entire container so background images can be full bleed
            Positioned.fill(
              child: PageView.builder(
                controller: _carouselController,
                itemCount: items.length,
                onPageChanged: (page) {
                  setState(() {
                    _carouselPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  final item = items[index];
                  final imageUrl = item['image_url'];
                  final overlayImageUrl = item['overlay_image_url'];
                  final overlayColorStr = item['overlay_color'];
                  final overlayOpacityVal = double.tryParse(item['overlay_opacity'] ?? '0.0') ?? 0.0;
                  final textColorStr = item['text_color'];
                  final borderColorStr = item['border_color'];

                  // Parse colors
                  Color? overlayColor;
                  if (overlayColorStr != null && overlayColorStr.isNotEmpty) {
                    overlayColor = _parseHexColor(overlayColorStr);
                  }
                  Color? textColor;
                  if (textColorStr != null && textColorStr.isNotEmpty) {
                    textColor = _parseHexColor(textColorStr);
                  }
                  Color? borderColor;
                  if (borderColorStr != null && borderColorStr.isNotEmpty) {
                    borderColor = _parseHexColor(borderColorStr);
                  }

                  // Default text colors: white if there is a background image, theme colors otherwise
                  final hasBgImage = imageUrl != null && imageUrl.isNotEmpty;
                  final defaultTitleColor = hasBgImage ? Colors.white : const Color(0xFF333333);
                  final defaultDescColor = hasBgImage ? Colors.white.withAlpha(220) : const Color(0xFF333333);

                  final titleStyle = TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor ?? defaultTitleColor,
                  );

                  final descStyle = TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: textColor?.withAlpha(220) ?? defaultDescColor,
                  );

                  return Container(
                    decoration: BoxDecoration(
                      border: borderColor != null
                          ? Border.all(color: borderColor, width: 2.0)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // 1. Background image
                          if (hasBgImage)
                            Positioned.fill(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, err, stack) => Container(
                                  color: AppColors.nocturnalExpedition.withAlpha(40),
                                ),
                              ),
                            ),

                          // 2. Custom Overlay Image (if uploaded)
                          if (overlayImageUrl != null && overlayImageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Image.network(
                                overlayImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, err, stack) => const SizedBox.shrink(),
                              ),
                            ),

                          // 3. Custom Overlay color or Default image overlay for readability
                          if (overlayColor != null && overlayOpacityVal > 0.0)
                            Positioned.fill(
                              child: Container(
                                color: overlayColor.withValues(alpha: overlayOpacityVal),
                              ),
                            )
                          else if (hasBgImage)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                            ),

                          // 4. Text content
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 50, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    style: titleStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item['desc'] ?? '',
                                    style: descStyle,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Page indicators in the top right
            Positioned(
              top: 10,
              right: 12,
              child: Row(
                children: List.generate(items.length, (index) {
                  final isSelected = _carouselPage == index;
                  final activeItem = items[_carouselPage < items.length ? _carouselPage : 0];
                  final hasBg = activeItem['image_url'] != null && activeItem['image_url']!.isNotEmpty;
                  final activeDotColor = hasBg ? Colors.white : AppColors.nocturnalExpedition;
                  final inactiveDotColor = hasBg ? Colors.white.withAlpha(100) : AppColors.mysticMint;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(left: 3),
                    width: isSelected ? 12 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isSelected ? activeDotColor : inactiveDotColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Activity list ────────────────────────────────────────────────────────
  Widget _buildActivityList() {
    final items = AttendeeService().recentActivity;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history_rounded,
                size: 40,
                color: AppColors.nocturnalExpedition.withAlpha(60),
              ),
              const SizedBox(height: 8),
              Text(
                'No recent activity yet',
                style: AppTextStyles.activitySubtitle,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isLast = i == items.length - 1;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.eventName, style: AppTextStyles.activityTitle),
                        const SizedBox(height: 2),
                        Text(item.detail, style: AppTextStyles.activitySubtitle),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF27AE60),
                    size: 22,
                  ),
                ],
              ),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFFEEF0EF)),
          ],
        );
      }),
    );
  }

  String _format24to12(String time24) {
    if (time24.isEmpty) return '--';
    final parts = time24.split(':');
    if (parts.isEmpty) return time24;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $ampm';
  }
}

/// Automatically scrolls its child chips horizontally in a loop if they overflow the card width.
class _AutoScrollingChips extends StatefulWidget {
  final List<Widget> children;
  final double spacing;

  const _AutoScrollingChips({
    required this.children,
    this.spacing = 8.0,
  });

  @override
  State<_AutoScrollingChips> createState() => _AutoScrollingChipsState();
}

class _AutoScrollingChipsState extends State<_AutoScrollingChips> {
  final ScrollController _scrollController = ScrollController();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  Future<void> _startAutoScroll() async {
    if (_isDisposed || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 1800));

    while (!_isDisposed && mounted && _scrollController.hasClients) {
      if (!_scrollController.position.hasContentDimensions) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(milliseconds: 1500));
        continue;
      }

      final forwardDuration = Duration(
        milliseconds: (maxScroll * 35).clamp(2000, 10000).toInt(),
      );

      if (!_scrollController.hasClients || _isDisposed || !mounted) break;
      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: forwardDuration,
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 1800));

      if (!_scrollController.hasClients || _isDisposed || !mounted) break;
      final returnDuration = Duration(
        milliseconds: (maxScroll * 25).clamp(1500, 8000).toInt(),
      );
      try {
        await _scrollController.animateTo(
          0.0,
          duration: returnDuration,
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 1800));
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < widget.children.length; i++) ...[
              widget.children[i],
              if (i < widget.children.length - 1)
                SizedBox(width: widget.spacing),
            ],
          ],
        ),
      ),
    );
  }
}
