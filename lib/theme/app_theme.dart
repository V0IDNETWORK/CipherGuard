import 'package:flutter/material.dart';
import '../core/config/constants.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kPrimary,
          secondary: kSecondary,
          surface: kSurface,
          error: kError,
        ),
        fontFamily: 'Rajdhani',
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: kText, fontWeight: FontWeight.w700, letterSpacing: 2),
          displayMedium: TextStyle(color: kText, fontWeight: FontWeight.w600, letterSpacing: 1.5),
          headlineLarge: TextStyle(color: kText, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          headlineMedium: TextStyle(color: kText, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: kText, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          bodyLarge: TextStyle(color: kText),
          bodyMedium: TextStyle(color: kTextDim),
          bodySmall: TextStyle(color: kTextDim, fontSize: 11),
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      );
}
