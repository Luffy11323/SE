// lib/screens/islamic_wellness/daily_hadith_screen.dart
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/strings.dart';
import 'package:self_evaluator/constants/colors.dart';

class DailyHadithScreen extends StatelessWidget {
  const DailyHadithScreen({super.key});

  // Dummy Hadith data
  final String hadithText =
      "The Prophet Muhammad (peace be upon him) said: \"The best among you are those who have the best character.\"";
  final String hadithSource = "Sahih Bukhari";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.dailyHadithTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 60,
                      color: AppColors.accentGreen,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      hadithText,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "- $hadithSource",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Reflect on how you can embody this teaching today.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
