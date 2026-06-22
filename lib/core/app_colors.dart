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
  static const Color nocturnalExpedition = Color(0xFF1900C4); // Vibrant Blue
  static const Color oceanicNoir = Color(0xFF0C0062);          // Deep Blue

  // ── Accent ─────────────────────────────────────────────────────────────────
  static const Color forsythia = Color(0xFF1900C4);
  static const Color deepSaffron = Color(0xFF0C0062);

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const Color arcticPowder = Color(0xFFF1F6F4);
  static const Color mysticMint = Color(0xFFD9E8E2);

  // ── Semantic aliases ───────────────────────────────────────────────────────
  static const Color background = arcticPowder;
  static const Color surface = Colors.white;
  static const Color primaryDark = oceanicNoir;
  static const Color accentYellow = forsythia;
  static const Color accentOrange = deepSaffron;

  // ── Gradient used on the splash screen ────────────────────────────────────
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      oceanicNoir,
      nocturnalExpedition,
    ],
  );
}
