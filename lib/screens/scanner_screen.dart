import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/app_colors.dart';
import '../core/file_downloader/file_downloader.dart';
import '../core/qr_pass_generator.dart';
import '../core/user_profile_service.dart';

/// Scanner / QR tab (tab 2).
/// Shows the LiFe white logo at the top, a single unified white card containing
/// the QR code and student information, a standalone "Download QR Code" button,
/// and the updated daily reset notice below.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isDownloading = false;

  Future<void> _downloadQr(UserProfileService profile) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      // Allow frame to render progress spinner before heavy canvas/image encoding
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // 1. Generate high-resolution branded pass PNG (with lifeBadge.png logo, QR, and info)
      Uint8List? pngBytes = await QrPassGenerator.generatePassPng(profile);

      // 2. Fallback to capturing on-screen card if generator returns null
      if (pngBytes == null) {
        final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          pngBytes = byteData?.buffer.asUint8List();
        }
      }

      if (pngBytes == null) {
        throw Exception('Could not render QR code image.');
      }

      // 3. Save / Download file
      final safeName = profile.name.isNotEmpty
          ? profile.name.replaceAll(RegExp(r'[^\w\-]'), '_')
          : (profile.email.isNotEmpty ? profile.email.split('@').first : 'pass');
      final fileName = 'LIFE_QR_$safeName.png';

      final success = await FileDownloader.saveImage(
        bytes: pngBytes,
        fileName: fileName,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'QR Code downloaded successfully!',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1B8755),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to save QR code to this device.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('QR Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to download QR code. Please check storage permissions and try again.',
            style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.splashGradient),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: UserProfileService(),
          builder: (context, _) {
            final profile = UserProfileService();
            return Column(
              children: [
                // ── LiFe white logo at the top ────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 8),
                  child: Image.asset(
                    'assets/lifeBadgeWhite.png',
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                ),

                // ── Center everything else in remaining space ─────────────
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewportConstraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          // Ensure content fills available height so it stays
                          // vertically centered when shorter than the screen.
                          constraints: BoxConstraints(
                            minHeight: viewportConstraints.maxHeight,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // ── Unified White Card (QR Code + User Info) ─
                                RepaintBoundary(
                                  key: _cardKey,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(35),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // QR Code
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final qrSize = constraints.maxWidth;
                                            return QrImageView(
                                              data: profile.toQrData(),
                                              version: QrVersions.auto,
                                              size: qrSize,
                                              backgroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 18),

                                        // Subtle Divider
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: AppColors.mysticMint.withAlpha(120),
                                        ),
                                        const SizedBox(height: 16),

                                        // Student Name
                                        Text(
                                          profile.name.isNotEmpty
                                              ? profile.name
                                              : 'UB Student',
                                          style: const TextStyle(
                                            fontFamily: 'Figtree',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.oceanicNoir,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),

                                        // Department | Program - Year Level
                                        Text(
                                          '${profile.department}  |  ${profile.program} - ${profile.yearLevel}',
                                          style: TextStyle(
                                            fontFamily: 'Figtree',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.nocturnalExpedition.withAlpha(200),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Download QR Code Button (Option 2: Glassmorphism Outlined Pill) ──
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: _isDownloading
                                        ? null
                                        : () => _downloadQr(profile),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white.withAlpha(35),
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isDownloading
                                        ? const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Preparing QR Code...',
                                                style: TextStyle(
                                                  fontFamily: 'Figtree',
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.download_rounded,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Download QR Code',
                                                style: TextStyle(
                                                  fontFamily: 'Figtree',
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ── Updated Notice text ───────────────────────────
                                Text(
                                  'Your generated QR Code is valid for one day and will reset at midnight.',
                                  style: TextStyle(
                                    fontFamily: 'Figtree',
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(190),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                // Bottom padding to account for floating navbar
                                SizedBox(height: 104.0 + MediaQuery.of(context).padding.bottom),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
