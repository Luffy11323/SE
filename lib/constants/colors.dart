// lib/constants/colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // ──────────────────────────────────────────────
  // Core dark theme
  // ──────────────────────────────────────────────
  static const Color primaryDark       = Color(0xFF1A0033); // Deep Purple (main bg)
  static const Color appBarBackground  = Color(0xFF1A0033); // Same as primaryDark for app bars
  static const Color cardBackground    = Color(0xFF2A004D); // Darker Purple for cards
  static const Color textLight         = Color(0xFFE0E0E0); // Light text / icons
  static const Color textDark          = Color(0xFF333333); // Dark text (rarely used)

  // ──────────────────────────────────────────────
  // Accents & interactive
  // ──────────────────────────────────────────────
  static const Color accentGreen       = Color(0xFF00FF80); // Neon green – main accent
  static const Color accentTeal        = Color(0xFF4ECDC4); // Calm secondary accent

  // ──────────────────────────────────────────────
  // Button & progress colors (your original ones)
  // ──────────────────────────────────────────────
  static const Color buttonPrimary     = Color(0xFF00FF80); // Button background
  static const Color buttonText        = Color(0xFF1A0033); // Text/icon on buttons
  static const Color progressIndicator = Color(0xFF00FF80); // Progress bars, loaders
  static const Color iconColor         = Color(0xFFE0E0E0); // Icons (light grey)

  // ──────────────────────────────────────────────
  // Status colors
  // ──────────────────────────────────────────────
  static const Color errorColor        = Color(0xFFFF0000); // Red for errors
  static const Color warningColor      = Color(0xFFFFA500); // Orange for warnings

  // ──────────────────────────────────────────────
  // Opacity helpers (use like AppColors.mutedText)
  // ──────────────────────────────────────────────
  static Color get mutedText    => textLight.withValues(alpha:0.7);
  static Color get faintAccent  => accentGreen.withValues(alpha:0.3);
  static Color get faintGreen   => accentGreen.withValues(alpha:0.25);
}