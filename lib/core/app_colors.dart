import 'package:flutter/material.dart';

/// Color palette for the LiFe App.
/// Blue-based brand system:
///   - nocturnalExpedition  #1900C4  Vibrant Blue (primary accent)
///   - oceanicNoir          #0C0062  Deep Blue (primary dark)
///   - arcticPowder         #F1F6F4  Light surface tint
///   - mysticMint           #D9E8E2  Border / divider tint
class AppColors {
  AppColors._();

  // ── Primary Brand ──────────────────────────────────────────────────────────
  static const Color nocturnalExpedition = Color(0xFF1900C4); // Vibrant Blue
  static const Color oceanicNoir = Color(0xFF0C0062);         // Deep Blue

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const Color arcticPowder = Color(0xFFF1F6F4);
  static const Color mysticMint = Color(0xFFD9E8E2);

  // ── Theme surface ──────────────────────────────────────────────────────────
  static const Color surface = Colors.white;

  // ── Semantic UI colors ─────────────────────────────────────────────────────
  /// Muted blue-grey used for subtitle text (e.g. activitySubtitle).
  static const Color subtleGray = Color(0xFF5A6E77);

  /// Light divider/border separators between list rows.
  static const Color dividerGray = Color(0xFFEEF0EF);

  /// Muted blue tint used on the QR screen for secondary text over gradient.
  static const Color mutedBlue = Color(0xFFAEC8CC);

  // ── Gradient used on the splash and auth screens ───────────────────────────
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      oceanicNoir,
      nocturnalExpedition,
    ],
  );
}
