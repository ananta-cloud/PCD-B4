import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography scale from DESIGN.md
abstract class AppTextStyles {
  /// Space Grotesk 32px/700 — headline-xl
  static TextStyle headlineXl({Color color = AppColors.onSurface}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        color: color,
      );

  /// Space Grotesk 24px/600 — headline-md
  static TextStyle headlineMd({Color color = AppColors.onSurface}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: color,
      );

  /// Inter 18px/400 — body-lg
  static TextStyle bodyLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: color,
      );

  /// Inter 16px/400 — body-md
  static TextStyle bodyMd({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: color,
      );

  /// Space Grotesk 40px/700 — numeric-display
  static TextStyle numericDisplay({Color color = AppColors.onSurface}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 48 / 40,
        letterSpacing: -1,
        color: color,
      );

  /// Space Grotesk 12px/600 UPPERCASE — label-caps
  static TextStyle labelCaps({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 1,
        color: color,
      );

  /// Inter 14px/500 — label standard
  static TextStyle label({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );
}
