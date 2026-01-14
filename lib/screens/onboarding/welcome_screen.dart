// lib/screens/onboarding/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/constants/app_routes.dart'; // ← add this file next if not already
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark,
              const Color(0xFF0F1A2A), // deeper midnight
              AppColors.primaryDark.withValues(alpha: 0.95),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animated title block
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 100,
                        color: AppColors.accentGreen.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.welcomeTitle,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                          letterSpacing: 0.8,
                          height: 1.15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.welcomeSubtitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textLight.withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Carousel of 3 gentle messages
              SizedBox(
                height: 280,
                child: CardSwiper(
                  cardsCount: 3,
                  numberOfCardsDisplayed: 1,
                  backCardOffset: const Offset(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  cardBuilder: (
                    BuildContext context,
                    int index,
                    int? horizontalSwipePercent,
                    int? verticalSwipePercent,
                  ) {
                    final cards = [
                      {
                        'title': 'A private sanctuary',
                        'text':
                            'Reflect and grow in complete privacy — no scores, no verdicts, no judgment.',
                      },
                      {
                        'title': 'Gentle guidance',
                        'text':
                            'Thoughtful questions and optional reminders rooted in mercy, patience, and self-accountability.',
                      },
                      {
                        'title': 'Your journey, your data',
                        'text':
                            'Everything stays with you. No sharing. No tracking. Just you and your growth.',
                      },
                    ];

                    final card = cards[index];

                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (0.03 * (1 - _controller.value)),
                          child: Opacity(
                            opacity: _controller.value,
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: AppColors.accentGreen.withValues(alpha: 0.18),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentGreen.withValues(alpha: 0.12),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    card['title']!,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textLight,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    card['text']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.45,
                                      color: AppColors.textLight.withValues(alpha: 0.85),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },

                ),
              ),

              const Spacer(flex: 2),

              // Big Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentGreen,
                          const Color(0xFF00CC66),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      AppStrings.continueButton,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.buttonText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}