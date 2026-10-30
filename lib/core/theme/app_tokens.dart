import 'package:all_commerce/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Design tokens that follow the active theme mode.
/// Access via `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.navBackground,
    required this.overlay,
  });

  /// Card background.
  final Color surface;

  /// Secondary surfaces (search fields, chips, skeletons).
  final Color surfaceMuted;

  /// Hairline border.
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Floating bottom bar background.
  final Color navBackground;

  /// Scrim / image overlay base (dark in both modes).
  final Color overlay;

  static const AppTokens light = AppTokens(
    surface: AppColors.card,
    surfaceMuted: AppColors.surfaceMutedLight,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
    shimmerBase: Color(0xFFEDEEF1),
    shimmerHighlight: Color(0xFFF8F9FA),
    navBackground: AppColors.card,
    overlay: Color(0xFF0B0F19),
  );

  static const AppTokens dark = AppTokens(
    surface: AppColors.cardDark,
    surfaceMuted: AppColors.surfaceMutedDark,
    border: AppColors.borderDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
    shimmerBase: Color(0xFF1A2030),
    shimmerHighlight: Color(0xFF242B3B),
    navBackground: AppColors.cardDark,
    overlay: Color(0xFF000000),
  );

  @override
  AppTokens copyWith({
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? navBackground,
    Color? overlay,
  }) {
    return AppTokens(
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      navBackground: navBackground ?? this.navBackground,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  /// Current design tokens (light/dark aware).
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
