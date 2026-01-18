// lib/widgets/loading_spinner.dart
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/colors.dart';

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
      ),
    );
  }
}
