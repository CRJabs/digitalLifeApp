import 'package:flutter/material.dart';

/// Color palette for the LiFe App.
/// Source: MP025 color system
/// - Arctic Powder  #F1F6F4
/// - Mystic Mint    #D9E8E2
/// - Forsythia      #FFC801
/// - Deep Saffron   #FF9932
/// - Nocturnal Expedition #114C5A
/// - Oceanic Noir   #172B36
class AppColors {
  AppColors._();

  // ── Primary Brand ──────────────────────────────────────────────────────────
  static const Color nocturnalExpedition = Color(0xFF114C5A);
  static const Color oceanicNoir = Color(0xFF172B36);

  // ── Accent ─────────────────────────────────────────────────────────────────
  static const Color forsythia = Color(0xFFFFC801);
  static const Color deepSaffron = Color(0xFFFF9932);

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const Color arcticPowder = Color(0xFFF1F6F4);
  static const Color mysticMint = Color(0xFFD9E8E2);

  // ── Semantic aliases ───────────────────────────────────────────────────────
  static const Color background = arcticPowder;
  static const Color surface = Colors.white;
  static const Color primaryDark = nocturnalExpedition;
  static const Color accentYellow = forsythia;
  static const Color accentOrange = deepSaffron;

  // ── Gradient used on the splash screen ────────────────────────────────────
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.55, 1.0],
    colors: [
      oceanicNoir,
      nocturnalExpedition,
      forsythia,
    ],
  );
}
