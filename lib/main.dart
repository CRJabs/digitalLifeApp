import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_colors.dart';
import 'core/app_text_styles.dart';
import 'core/user_profile_service.dart';
import 'core/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Notification Service
  try {
    await NotificationService.initialize();
  } catch (e, stackTrace) {
    debugPrint('Notification service initialization failed: $e\n$stackTrace');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://fsczvbsfhuenrzwxtgyq.supabase.co',
      publishableKey: 'sb_publishable_PtsfIjaL-mJUC8hBcHd0fw_sDYj6iWU',
    );
  } catch (e, stackTrace) {
    debugPrint('Supabase initialization failed: $e\n$stackTrace');
  }

  // Initialize daily rotation
  try {
    UserProfileService().startDailyRotation();
  } catch (e, stackTrace) {
    debugPrint('UserProfileService startDailyRotation failed: $e\n$stackTrace');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LifeApp());
}

class LifeApp extends StatelessWidget {
  const LifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiFe – Log of Informative and Fun-Filled Experiences',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Figtree',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.nocturnalExpedition,
          primary: AppColors.nocturnalExpedition,
          secondary: AppColors.nocturnalExpedition,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: Colors.white,
        // ── Input decoration ──────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: AppTextStyles.inputHint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.mysticMint),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.mysticMint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: AppColors.nocturnalExpedition,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
        // ── Elevated button ───────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.nocturnalExpedition,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.nocturnalExpedition.withAlpha(100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(double.infinity, 52),
            textStyle: AppTextStyles.button,
            elevation: 0,
          ),
        ),
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        const double maxContentWidth = 820.0; // iPad Air portrait width

        if (mq.size.width > maxContentWidth) {
          // On desktop/wide screens: fixed text scale, content centered at 820px
          // with white background filling the remaining space on each side.
          return Container(
            color: Colors.white,
            child: Center(
              child: SizedBox(
                width: maxContentWidth,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: Size(maxContentWidth, mq.size.height),
                    textScaler: const TextScaler.linear(1.0),
                  ),
                  child: child!,
                ),
              ),
            ),
          );
        }

        // On mobile/narrow screens: scale text relative to a 360px base phone width.
        final scale = (mq.size.width / 360.0).clamp(0.85, 1.15);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
