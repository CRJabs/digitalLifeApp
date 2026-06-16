import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// A single attendance event row inside an accordion section.
class _AttendanceItem {
  const _AttendanceItem({required this.title, required this.date});
  final String title;
  final String date;
}

/// Activity History screen (tab 2).
/// Shows collapsible semester/event sections.  Each expanded section lists
/// attendance events with AM and PM time-in / time-out indicator boxes.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Track which sections are expanded
  final Map<int, bool> _expanded = {0: true, 1: false, 2: false, 3: false};

  static const _sections = [
    _SectionData(
      title: 'First Semester',
      items: [
        _AttendanceItem(title: 'Lorem Ipsum', date: 'XXX __, 2026'),
        _AttendanceItem(title: 'Lorem Ipsum', date: 'XXX __, 2026'),
        _AttendanceItem(title: 'Lorem Ipsum', date: 'XXX __, 2026'),
        _AttendanceItem(title: 'Lorem Ipsum', date: 'XXX __, 2026'),
        _AttendanceItem(title: 'Lorem Ipsum', date: 'XXX __, 2026'),
      ],
    ),
    _SectionData(title: 'Second Semester', items: []),
    _SectionData(title: 'UBDays 2026', items: []),
    _SectionData(title: 'Other Events', items: []),
  ];

  void _toggle(int index) {
    setState(() => _expanded[index] = !(_expanded[index] ?? false));
  }

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

          // ── Accordion list ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: List.generate(_sections.length, (i) {
                  return _buildSection(i);
                }),
              ),
            ),
          ),

          // ── LiFe logo pinned above nav ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Image.asset(
              'assets/lifeColored.png',
              height: 38,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(int index) {
    final section = _sections[index];
    final isExpanded = _expanded[index] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          // ── Section header ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => _toggle(index),
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
                    section.title,
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

          if (isExpanded && section.items.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: AppColors.mysticMint,
                  width: 1,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: Column(
                children: List.generate(section.items.length, (j) {
                  final item = section.items[j];
                  final isLast = j == section.items.length - 1;
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

  Widget _buildAttendanceRow(_AttendanceItem item) {
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
                Text(item.title, style: AppTextStyles.activityTitle),
                const SizedBox(height: 2),
                Text(
                  item.date,
                  style: AppTextStyles.activitySubtitle.copyWith(
                    color: AppColors.nocturnalExpedition,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // AM / PM time-in & time-out boxes
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTimePair('AM'),
              const SizedBox(height: 4),
              _buildTimePair('PM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePair(String label) {
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
        _TimeBox(),
        const SizedBox(width: 4),
        _TimeBox(),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 20,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.nocturnalExpedition, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Internal data class for accordion sections.
class _SectionData {
  const _SectionData({required this.title, required this.items});
  final String title;
  final List<_AttendanceItem> items;
}
