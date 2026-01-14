// lib/screens/self_eval/reflection_home_screen.dart

import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/constants/app_routes.dart';

class ReflectionHomeScreen extends StatefulWidget {
  const ReflectionHomeScreen({super.key});

  @override
  State<ReflectionHomeScreen> createState() => _ReflectionHomeScreenState();
}

class _ReflectionHomeScreenState extends State<ReflectionHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Back / close button (optional — can go back to dashboard)
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.textLight),
                onPressed: () => Navigator.pop(context),
              ),

              const Spacer(flex: 2),

              // Gentle header with subtle glow
              FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Personal Growth Reflection",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                          height: 1.15,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: AppColors.accentGreen.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "A quiet, private space to look inward.\n"
                        "No scores. No judgment.\n"
                        "Just honest answers and gentle patterns.",
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.5,
                          color: AppColors.textLight.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // The only action — big, soft, inviting
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.reflectionQuestions);
                  },
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentGreen.withValues(alpha: 0.88),
                          const Color(0xFF00B366),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.38),
                          blurRadius: 32,
                          spreadRadius: 6,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 56,
                          color: AppColors.primaryDark.withValues(alpha: 0.95),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Begin Reflection",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "10–15 gentle questions",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primaryDark.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}