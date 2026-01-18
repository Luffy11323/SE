// lib/screens/islamic_wellness/daily_dua_screen.dart
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/strings.dart';
import 'package:self_evaluator/constants/colors.dart';

class DailyDuaScreen extends StatelessWidget {
  const DailyDuaScreen({super.key});

  // Dummy Dua data
  final String arabicDua = "اللهم إني أسألك العافية في الدنيا والآخرة";
  final String transliteration =
      "Allahumma inni as'alukal-'afiyah fid-dunya wal-akhirah.";
  final String englishMeaning =
      "O Allah, I ask You for well-being in this world and the Hereafter.";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.dailyDuaTitle)),
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
                      Icons.handshake,
                      size: 60,
                      color: AppColors.accentGreen,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      arabicDua,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontFamily: 'ArabicFont',
                        fontSize: 30,
                      ), // Placeholder for Arabic font
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      transliteration,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      englishMeaning,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Make this beautiful supplication a part of your daily routine.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
