import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:self_evaluator/constants/app_routes.dart'; // ← we'll create this later
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:firebase_auth/firebase_auth.dart'; // if using Firebase

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Video setup
    _controller = VideoPlayerController.asset('assets/vid/splash1.mp4')
      ..setPlaybackSpeed(2.0)           // 2x speed
      ..setLooping(false)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });

    // Gentle fade-in animation for text (portal opening feel)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Auto-redirect after exactly 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Already logged in → go to dashboard
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      } else {
        // Not logged in → go to welcome
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video background (portal-like entrance)
          if (_controller.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.accentGreen)),

          // Semi-transparent overlay so text is readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark.withValues(alpha: 0.4),
                  AppColors.primaryDark.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),

          // Centered content with fade-in
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon (you can replace with your own asset or keep Icon)
                  Icon(
                    Icons.self_improvement_rounded,
                    size: 120,
                    color: AppColors.accentGreen.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 24),

                  // App name
                  Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    AppStrings.tagline,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textLight.withValues(alpha: 0.85),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}