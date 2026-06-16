import 'package:flutter/material.dart';

/// Shared text styles using the Host Grotesk variable font.
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'HostGrotesk';

  static const TextStyle splashTagline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    letterSpacing: 2.4,
  );

  static const TextStyle loginTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Color(0xFF172B36),
  );

  static const TextStyle inputHint = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF114C5A),
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.4,
  );

  static const TextStyle welcomeLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF172B36),
  );

  static const TextStyle welcomeName = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: Color(0xFF172B36),
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF172B36),
  );

  static const TextStyle seeAll = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFF114C5A),
  );

  static const TextStyle activityTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF172B36),
  );

  static const TextStyle activitySubtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF5A6E77),
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );
}
