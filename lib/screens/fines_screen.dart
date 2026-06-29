import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_date_utils.dart';
import '../core/app_text_styles.dart';
import '../core/attendee_service.dart';

/// Fines / Outstanding Dues Screen (tab 1).
/// Displays the accumulated dues, the list of events with missing AM/PM check boxes,
/// and the read-only notices card populated from Supabase.
class FinesScreen extends StatefulWidget {
  const FinesScreen({super.key});

  @override
  State<FinesScreen> createState() => _FinesScreenState();
}

class _FinesScreenState extends State<FinesScreen> {
  final PageController _finesCardController = PageController();
  int _finesCardPage = 0;

  @override
  void initState() {
    super.initState();
    AttendeeService().addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    AttendeeService().removeListener(_onServiceUpdate);
    _finesCardController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() => setState(() {});


  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final service = AttendeeService();
    final missingChecks = service.getMissingChecks();

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
                        'Outstanding Dues',
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

          // ── Scrollable Body ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                120,
              ), // Adjusted padding (no floating logo)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Outstanding Dues Count Card ───────────────────────
                  _buildDuesCard(service.outstandingDues),
                  const SizedBox(height: 24),

                  // ── Notices Section ─────────────────────────────────────
                  _buildNoticesField(service.studentNotice),
                  const SizedBox(height: 24),

                  // ── Section Title ───────────────────────────────────────
                  Text('Missed Attendances', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),

                  // ── Missing Checks List ─────────────────────────────────
                  if (missingChecks.isEmpty)
                    _buildEmptyState()
                  else
                    Column(
                      children: missingChecks
                          .map((info) => _buildMissingCheckRow(info))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Outstanding Dues Card (Swipeable) ───────────────────────────────────
  Widget _buildDuesCard(double dues) {
    final equivalentHours = (dues / 50.0);

    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: AppColors.oceanicNoir,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.oceanicNoir.withAlpha(70),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _finesCardController,
              onPageChanged: (p) => setState(() => _finesCardPage = p),
              children: [
                // Page 1: Total Accumulated Fines
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total Accumulated Fines',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₱${dues.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱25.00 fine per missing attendance',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withAlpha(160),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Page 2: Equivalent Hours to render
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Equivalent Hours to Render',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${equivalentHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 hour per ₱50 accumulated dues',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withAlpha(160),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Dots indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                2,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: _finesCardPage == i ? 12 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _finesCardPage == i ? Colors.white : Colors.white.withAlpha(100),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Missing Check Row ────────────────────────────────────────────────────
  Widget _buildMissingCheckRow(MissingCheckInfo info) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mysticMint, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.eventName,
                      style: AppTextStyles.activityTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppDateUtils.formatDate(info.date),
                      style: AppTextStyles.activitySubtitle.copyWith(
                        color: AppColors.nocturnalExpedition,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '₱${info.totalFine.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEF0EF)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: info.missingSlots.map((slot) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.arcticPowder,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.mysticMint, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cancel_rounded,
                      color: Colors.redAccent,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      slot,
                      style: AppTextStyles.activitySubtitle.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Notices Field (Read-only) ────────────────────────────────────────────
  Widget _buildNoticesField(String noticeText) {
    final displayText = noticeText.trim().isEmpty
        ? 'No announcements at this time.'
        : noticeText;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.arcticPowder,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.mysticMint, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.oceanicNoir,
              ),
              const SizedBox(width: 8),
              Text(
                'Official Notice',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.oceanicNoir,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayText,
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.arcticPowder,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mysticMint, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_rounded, size: 40, color: Colors.green.shade600),
          const SizedBox(height: 8),
          Text(
            'All Cleared!',
            style: AppTextStyles.activityTitle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You do not have any missing attendance.',
            style: AppTextStyles.activitySubtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
