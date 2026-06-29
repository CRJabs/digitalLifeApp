import 'package:flutter/material.dart';
import '../core/user_profile_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'home_screen.dart';
import 'fines_screen.dart';
import 'scanner_screen.dart';
import 'activity_screen.dart';
import 'settings_screen.dart';

/// Root shell for the five main tabs.
/// Uses an [IndexedStack] to keep all screens alive while preserving state.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UserProfileService().startDailyRotation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      // HomeScreen gets a callback so the "View QR Code" card can jump to tab 2 (Scan)
      HomeScreen(
        onViewQrTap: () => setState(() => _currentIndex = 2),
        onSeeAllTap: () => setState(() => _currentIndex = 3),
      ),
      const FinesScreen(),
      const ScannerScreen(),
      ActivityScreen(isActive: _currentIndex == 3),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: screens),

          // ── Fade background for navbar ──────────────────────────────────
          if (_currentIndex != 0 && _currentIndex != 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 142,
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
                      stops: const [0.0, 0.75, 0.9, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // ── Floating bottom navigation bar ──────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 32.0,
            child: AppBottomNav(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}
