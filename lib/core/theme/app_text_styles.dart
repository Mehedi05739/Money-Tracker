import 'package:flutter/material.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle displayAmount = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(fontSize: 15.5, height: 1.4);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, height: 1.4);
  static const TextStyle bodySmall = TextStyle(fontSize: 12.5, height: 1.35);

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Tabular figures keep amount columns aligned as digits change.
  static const TextStyle amount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme(Color onSurface) => TextTheme(
    displaySmall: displayAmount.copyWith(color: onSurface),
    headlineLarge: headlineLarge.copyWith(color: onSurface),
    headlineMedium: headlineMedium.copyWith(color: onSurface),
    headlineSmall: titleLarge.copyWith(color: onSurface),
    titleLarge: titleLarge.copyWith(color: onSurface),
    titleMedium: titleMedium.copyWith(color: onSurface),
    titleSmall: titleMedium.copyWith(fontSize: 13.5, color: onSurface),
    bodyLarge: bodyLarge.copyWith(color: onSurface),
    bodyMedium: bodyMedium.copyWith(color: onSurface),
    bodySmall: bodySmall.copyWith(color: onSurface),
    labelSmall: caption.copyWith(color: onSurface),
  );
}
