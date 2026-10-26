import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_colors.dart';
import 'user_profile_service.dart';

/// Generates a high-resolution, branded Student LiFe Pass PNG image.
class QrPassGenerator {
  /// Renders a digital pass badge with:
  /// - LiFe logo (`assets/lifeBadge.png`)
  /// - QR code
  /// - Student Name
  /// - Department, Program & Year Level
  static Future<Uint8List?> generatePassPng(UserProfileService profile) async {
    try {
      const double width = 720;
      const double height = 820;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

      // 1. White Background with rounded corners
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, width, height),
          const Radius.circular(32),
        ),
        bgPaint,
      );

      // Subtle border
      final borderPaint = Paint()
        ..color = AppColors.mysticMint.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1.5, 1.5, width - 3, height - 3),
          const Radius.circular(32),
        ),
        borderPaint,
      );

      // 2. Draw LiFe Badge Logo at Top
      try {
        final ByteData data = await rootBundle.load('assets/lifeBadge.png');
        final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final ui.FrameInfo fi = await codec.getNextFrame();
        final ui.Image badgeImg = fi.image;

        const double targetBadgeHeight = 76;
        final double targetBadgeWidth = targetBadgeHeight * (badgeImg.width / badgeImg.height);
        final double badgeLeft = (width - targetBadgeWidth) / 2;
        const double badgeTop = 52;

        canvas.drawImageRect(
          badgeImg,
          Rect.fromLTWH(0, 0, badgeImg.width.toDouble(), badgeImg.height.toDouble()),
          Rect.fromLTWH(badgeLeft, badgeTop, targetBadgeWidth, targetBadgeHeight),
          Paint(),
        );
      } catch (e) {
        debugPrint('Failed to load lifeBadge.png: $e');
      }

      // 3. Draw QR Code in Center
      const double qrSize = 460;
      final double qrLeft = (width - qrSize) / 2;
      const double qrTop = 160;

      final qrPainter = QrPainter(
        data: profile.toQrData(),
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.oceanicNoir,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.oceanicNoir,
        ),
      );

      canvas.save();
      canvas.translate(qrLeft, qrTop);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();

      // 4. Subtle Divider Line
      const double dividerY = qrTop + qrSize + 36;
      final dividerPaint = Paint()
        ..color = AppColors.mysticMint.withAlpha(140)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        const Offset(60, dividerY),
        const Offset(width - 60, dividerY),
        dividerPaint,
      );

      // 5. Student Name
      final namePainter = TextPainter(
        text: TextSpan(
          text: profile.name.isNotEmpty ? profile.name : 'UB Student',
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.oceanicNoir,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 80);

      final double nameLeft = (width - namePainter.width) / 2;
      final double nameTop = dividerY + 28;
      namePainter.paint(canvas, Offset(nameLeft, nameTop));

      // 6. Department | Program - Year Level
      final deptText = '${profile.department}  |  ${profile.program} - ${profile.yearLevel}';
      final deptPainter = TextPainter(
        text: TextSpan(
          text: deptText,
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.nocturnalExpedition.withAlpha(200),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 80);

      final double deptLeft = (width - deptPainter.width) / 2;
      final double deptTop = nameTop + namePainter.height + 10;
      deptPainter.paint(canvas, Offset(deptLeft, deptTop));



      // 8. Convert to PNG bytes
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error generating pass PNG: $e');
      return null;
    }
  }
}
