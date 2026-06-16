import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/app_colors.dart';
import 'core/app_text_styles.dart';
import 'core/user_profile_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  UserProfileService().startHourlyRotation();
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
        fontFamily: 'HostGrotesk',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.nocturnalExpedition,
          primary: AppColors.nocturnalExpedition,
          secondary: AppColors.forsythia,
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
      home: const SplashScreen(),
    );
  }
}
