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

  @override
  void initState() {
    super.initState();
    AttendeeService().addListener(_onAttendeeUpdate);
    UserProfileService().addListener(_onProfileUpdate);
    _carouselController = PageController(initialPage: 0);
    _fetchCarouselItems();
    _subscribeToCarousel();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _carouselChannel?.unsubscribe();
    _carouselTimer?.cancel();
    _carouselController.dispose();
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 240), // Large bottom padding to scroll past floating carousel + navbar
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOutstandingDuesCard(),
                      _buildViewQrCard(),
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
            height: 260,
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

  // ── Outstanding Dues card ────────────────────────────────────────────────
  Widget _buildOutstandingDuesCard() {
    final dues = AttendeeService().outstandingDues;
    return Container(
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
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.oceanicNoir.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: AppColors.oceanicNoir,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Outstanding Fines',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF5A6E77),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₱${dues.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 22,
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

  // ── View QR Code card ────────────────────────────────────────────────────
  Widget _buildViewQrCard() {
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
                // Icon box
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
    const double carouselHeight = 90.0;

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
                  final defaultTitleColor = hasBgImage ? Colors.white : AppColors.oceanicNoir;
                  final defaultDescColor = hasBgImage ? Colors.white.withAlpha(220) : Colors.black87;

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
                                color: overlayColor.withOpacity(overlayOpacityVal),
                              ),
                            )
                          else if (hasBgImage)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.35),
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
                                    maxLines: 2,
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
}
