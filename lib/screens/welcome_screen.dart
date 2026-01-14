// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/widgets/custom_button.dart';
import 'package:self_evaluator/screens/login_screen.dart'; // Import login screen

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              Icons.psychology_alt, // Example icon
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
            Text(
              AppStrings.welcomeSubtitle,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            CustomButton(
              text: AppStrings.continueButton,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
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
