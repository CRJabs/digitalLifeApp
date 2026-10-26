import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_colors.dart';
import 'core/app_text_styles.dart';
import 'core/user_profile_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'UB L.I.F.E.',
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
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.mysticMint),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.mysticMint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.nocturnalExpedition,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 52),
            textStyle: AppTextStyles.button,
            elevation: 0,
          ),
        ),
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final isBigScreen = mq.size.width > 600;

        if (isBigScreen) {
          // Whenever the web app is opened on a big screen (e.g. desktop/tablet),
          // show a white background with lifeBadge.png and the mobile advisory message.
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/lifeBadge.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'This web app was made primarily for mobile use and will be deployed as an application in the foreseeable future. For the best usage experience, open the web app on a mobile device',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                          color: AppColors.oceanicNoir,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
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
