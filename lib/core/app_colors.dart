import 'package:flutter/material.dart';

/// Smart Receipt Scanner — Design System Colors
/// Sourced from DESIGN.md
abstract class AppColors {
  // Surfaces
  static const Color surface = Color(0xFF11131C);
  static const Color surfaceDim = Color(0xFF11131C);
  static const Color surfaceBright = Color(0xFF373943);
  static const Color surfaceContainerLowest = Color(0xFF0C0E17);
  static const Color surfaceContainerLow = Color(0xFF191B24);
  static const Color surfaceContainer = Color(0xFF1D1F29);
  static const Color surfaceContainerHigh = Color(0xFF282933);
  static const Color surfaceContainerHighest = Color(0xFF33343E);
  static const Color surfaceCard = Color(0xFF1C1C1E);

  // On-Surface
  static const Color onSurface = Color(0xFFE2E1EF);
  static const Color onSurfaceVariant = Color(0xFFC4C5D9);
  static const Color inverseSurface = Color(0xFFE2E1EF);
  static const Color inverseOnSurface = Color(0xFF2E303A);

  // Outline
  static const Color outline = Color(0xFF8E90A2);
  static const Color outlineVariant = Color(0xFF434656);

  // Primary
  static const Color surfaceTint = Color(0xFFB8C3FF);
  static const Color primary = Color(0xFFB8C3FF);
  static const Color onPrimary = Color(0xFF002388);
  static const Color primaryContainer = Color(0xFF2E5BFF);
  static const Color onPrimaryContainer = Color(0xFFEFEFFF);
  static const Color inversePrimary = Color(0xFF124AF0);

  // Secondary (Green — success)
  static const Color secondary = Color(0xFF40E56C);
  static const Color onSecondary = Color(0xFF003912);
  static const Color secondaryContainer = Color(0xFF02C953);
  static const Color onSecondaryContainer = Color(0xFF004D1B);

  // Tertiary (Orange)
  static const Color tertiary = Color(0xFFFFB59B);
  static const Color onTertiary = Color(0xFF5B1A00);
  static const Color tertiaryContainer = Color(0xFFC24100);
  static const Color onTertiaryContainer = Color(0xFFFFECE6);

  // Error
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Background
  static const Color background = Color(0xFF11131C);
  static const Color onBackground = Color(0xFFE2E1EF);
  static const Color surfaceVariant = Color(0xFF33343E);

  // Custom — Scanner
  static const Color scannerOverlay = Color(0x66000000);
  static const Color successGlint = Color(0xFF00E676);
  static const Color boundingBoxDefault = Color(0xFFFFFFFF);
  static const Color syncStatusPending = Color(0xFFFFAB00);
}
