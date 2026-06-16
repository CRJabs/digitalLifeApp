import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/user_profile_service.dart';

/// Data model for a recent-activity list item.
class _ActivityItem {
  const _ActivityItem({required this.eventName, required this.detail});
  final String eventName;
  final String detail;
}

/// Home / main screen (tab 0).
/// Shows a welcome header, the "View QR Code" action card, and a
/// Recent Activity list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onViewQrTap});

  /// Called when the user taps the "View QR Code" card; used by [MainShell]
  /// to switch to the Scanner tab.
  final VoidCallback? onViewQrTap;

  static const List<_ActivityItem> _activities = [
    _ActivityItem(
      eventName: 'Panagdait Fair 2026',
      detail: 'Attendance timed out',
    ),
    _ActivityItem(
      eventName: 'Panagdait Fair 2026',
      detail: 'Attendance timed in',
    ),
    _ActivityItem(
      eventName: 'General Orientation 2026',
      detail: 'Attendance timed out',
    ),
    _ActivityItem(
      eventName: 'General Orientation 2026',
      detail: 'Attendance timed in',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: UserProfileService(),
      builder: (context, _) {
        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              _buildHeader(mq),

              // ── Scrollable body ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
        );
      },
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(MediaQueryData mq) {
    final profile = UserProfileService();
    final parts = profile.name.trim().split(' ');
    final displayName = parts.length > 1 ? '${parts[0]} ${parts[1]}' : profile.name;

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
          onTap: onViewQrTap,
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
                          fontFamily: 'HostGrotesk',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Check your attendance',
                        style: TextStyle(
                          fontFamily: 'HostGrotesk',
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
        Text('See all', style: AppTextStyles.seeAll),
      ],
    );
  }

  // ── Activity list ────────────────────────────────────────────────────────
  Widget _buildActivityList() {
    return Column(
      children: List.generate(_activities.length, (i) {
        final item = _activities[i];
        final isLast = i == _activities.length - 1;
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
                        Text(item.eventName,
                            style: AppTextStyles.activityTitle),
                        const SizedBox(height: 2),
                        Text(item.detail,
                            style: AppTextStyles.activitySubtitle),
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
            if (!isLast)
              const Divider(height: 1, color: Color(0xFFEEF0EF)),
          ],
        );
      }),
    );
  }
}
