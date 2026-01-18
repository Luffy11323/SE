import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_evaluator/constants/strings.dart';
import 'package:self_evaluator/widgets/custom_button.dart';
import 'package:self_evaluator/screens/login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showJudgementFreeTooltip = false;

  @override
  void initState() {
    super.initState();
    _checkTooltipStatus();
  }

  Future<void> _checkTooltipStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen =
        prefs.getBool('seen_judgement_free_tooltip') ?? false;

    if (!hasSeen) {
      setState(() {
        _showJudgementFreeTooltip = true;
      });

      await prefs.setBool('seen_judgement_free_tooltip', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            Icon(
              Icons.psychology_alt,
              size: 120,
              color: Theme.of(context).colorScheme.secondary,
            ),

            const SizedBox(height: 30),

            Text(
              AppStrings.welcomeTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    AppStrings.welcomeSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),

                if (_showJudgementFreeTooltip) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        "This is a private, judgment-free space.\n"
                        "No scores. No verdicts. Just gentle reflection.",
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.textLight.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),

            const Spacer(),

            CustomButton(
              text: AppStrings.continueButton,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
