// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';

// Active screens (only these exist now)
import 'package:self_evaluator/screens/onboarding/splash_screen.dart';
import 'package:self_evaluator/screens/onboarding/welcome_screen.dart';
import 'package:self_evaluator/screens/onboarding/login_screen.dart';
import 'package:self_evaluator/screens/onboarding/signup_screen.dart';
import 'package:self_evaluator/screens/onboarding/complete_profile_screen.dart';
import 'package:self_evaluator/screens/dashboard_screen.dart';
import 'package:self_evaluator/screens/self_eval/reflection_home_screen.dart';
import 'package:self_evaluator/screens/self_eval/reflection_questions_screen.dart';
import 'package:self_evaluator/screens/self_eval/reflection_summary_screen.dart';
import 'package:self_evaluator/screens/self_eval/reflection_history_screen.dart';
import 'package:self_evaluator/screens/profile/settings_screen.dart';

// Constants
import 'package:self_evaluator/constants/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: 'https://jjnbusmjsgjyjgomhuij.supabase.co', // your Supabase URL
    anonKey: 'sb_publishable_b2j324qGKaNE_gL-CuiiFw_R8X2aBEp', // ← your ANON key (not service_role!)
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Self Evaluator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: AppColors.primaryDark,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textLight),
          bodyMedium: TextStyle(color: AppColors.textLight),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textLight,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.textLight),
        ),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        Widget page;

        switch (settings.name) {
          case AppRoutes.splash:
            page = const SplashScreen();
            break;

          case AppRoutes.welcome:
            page = const WelcomeScreen();
            break;

          case AppRoutes.login:
            page = const LoginScreen();
            break;

          case AppRoutes.signup:
            page = const SignupScreen();
            break;

          case AppRoutes.completeProfile:
            page = const CompleteProfileScreen();
            break;

          case AppRoutes.dashboard:
            page = const DashboardScreen();
            break;

          case AppRoutes.reflectionHome:
            page = const ReflectionHomeScreen();
            break;

          case AppRoutes.reflectionQuestions:
            page = const ReflectionQuestionsScreen();
            break;

          case AppRoutes.reflectionSummary:
            // Expect arguments: {'answers': Map<String, int>, 'startedAt': DateTime?}
            final args = settings.arguments as Map<String, dynamic>?;
            page = ReflectionSummaryScreen(
              answers: args?['answers'] as Map<String, int>? ?? {},
              startedAt: args?['startedAt'] as DateTime?,
            );
            break;

          case AppRoutes.reflectionHistory:
            page = const ReflectionHistoryScreen();
            break;

          case AppRoutes.settings:
            page = const SettingsScreen();
            break;

          default:
            page = const Scaffold(
              body: Center(child: Text('404 - Page not found')),
            );
        }

        return MaterialPageRoute(builder: (_) => page);
      },
    );
  }
}