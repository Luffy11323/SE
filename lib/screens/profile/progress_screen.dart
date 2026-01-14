// lib/screens/profile/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/string_constants.dart';
import 'package:self_evaluator/constants/color_palette.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  // Dummy data for progress
  final Map<String, double> dummyProgress = const {
    'Professional Life': 0.75,
    'Emotional Self': 0.60,
    'Social Life': 0.80,
    'Intelligence (IQ)': 0.70,
    'Religious Self': 0.90,
    'Identity / Core Values': 0.85,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.progressTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your Self-Growth Overview",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: dummyProgress.length,
                itemBuilder: (context, index) {
                  final category = dummyProgress.keys.elementAt(index);
                  final progress = dummyProgress.values.elementAt(index);
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.cardBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress > 0.7
                                  ? AppColors.accentGreen
                                  : progress > 0.4
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 5),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              '${(progress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
