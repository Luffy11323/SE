// lib/widgets/custom_button.dart (Modified)
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/color_palette.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.buttonPrimary,
        foregroundColor: textColor ?? AppColors.buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      child: Text(text),
    );
  }
}
