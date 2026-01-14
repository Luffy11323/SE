// lib/screens/islamic_wellness/spiritual_eval_screen.dart
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/string_constants.dart';

class SpiritualEvalScreen extends StatelessWidget {
  const SpiritualEvalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.spiritualReflectionTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.self_improvement,
                size: 80,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 20),
              Text(
                "This section will feature deeper spiritual reflection questions or mood check-ins.",
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Coming soon: MCQs to evaluate your spiritual state and growth.",
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
