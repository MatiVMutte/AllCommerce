import 'package:flutter/material.dart';

/// Raw palette. Prefer `context.tokens` (AppTokens) in widgets — these
/// constants are the source for the token/theme definitions.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF0052FF);
  static const Color primaryDark = Color(0xFF3D7BFF);

  // Light
  static const Color background = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF5F6F8);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF0B0F19);
  static const Color textSecondary = Color(0xFF5B6472);
  static const Color textTertiary = Color(0xFF98A2B3);

  // Dark
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color cardDark = Color(0xFF131826);
  static const Color surfaceMutedDark = Color(0xFF1A2030);
  static const Color borderDark = Color(0xFF242B3B);
  static const Color textPrimaryDark = Color(0xFFF5F7FA);
  static const Color textSecondaryDark = Color(0xFFA0A8B8);
  static const Color textTertiaryDark = Color(0xFF667085);

  // Semantic (same both modes)
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  /// Legacy alias kept for existing code paths.
  static const Color accent = primary;
}
