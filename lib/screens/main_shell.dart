import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import 'home_screen.dart';
import 'scanner_screen.dart';
import 'activity_screen.dart';
import 'settings_screen.dart';

/// Root shell for the four main tabs.
/// Uses an [IndexedStack] to keep all screens alive while preserving state.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      // HomeScreen gets a callback so the "View QR Code" card can jump to tab 1
      HomeScreen(onViewQrTap: () => setState(() => _currentIndex = 1)),
      const ScannerScreen(),
      const ActivityScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Show the LiFe logo above the navbar on Activity (2) and Settings (3) tabs.
    final showLogo = _currentIndex == 2 || _currentIndex == 3;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),

          // ── LiFe logo — floats just above the bottom navbar ─────────────
          if (showLogo)
            Positioned(
              left: 0,
              right: 0,
              // 32px navbar bottom offset + ~60px nav height + 24px gap
              bottom: 116,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/lifeColored.png',
                  height: 38,
                  fit: BoxFit.contain,
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
