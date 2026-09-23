import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Spacing System
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // Corner Radius System (16-24px radius per specifications)
  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  static ThemeData get lightTheme {
    return FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: AppColors.primaryEmergencyRed,
        primaryContainer: Color(0xFFFFDAD6),
        secondary: AppColors.warmSignalAmber,
        secondaryContainer: Color(0xFFFFDCC3),
        tertiary: AppColors.safeEmerald,
        tertiaryContainer: Color(0xFFC7F0D8),
        appBarColor: AppColors.primaryEmergencyRed,
        error: AppColors.deepEmergencyRed,
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 4,
      subThemesData: const FlexSubThemesData(
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: radiusM,
        inputDecoratorUnfocusedHasBorder: true,
        inputDecoratorFocusedHasBorder: true,
        inputDecoratorFillColor: Colors.transparent,
        inputDecoratorIsFilled: false,
        cardRadius: radiusL,
        buttonPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        outlinedButtonBorderWidth: 1.5,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackground: AppColors.lightBackground,
    );
  }

  static ThemeData get darkTheme {
    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: AppColors.primaryEmergencyRed,
        primaryContainer: Color(0xFF930006),
        secondary: AppColors.warmSignalAmber,
        secondaryContainer: Color(0xFF7A4300),
        tertiary: AppColors.safeEmerald,
        tertiaryContainer: Color(0xFF00522B),
        appBarColor: AppColors.darkSurface,
        error: AppColors.deepEmergencyRed,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 8,
      subThemesData: const FlexSubThemesData(
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: radiusM,
        inputDecoratorUnfocusedHasBorder: true,
        inputDecoratorFocusedHasBorder: true,
        inputDecoratorFillColor: Colors.transparent,
        inputDecoratorIsFilled: false,
        cardRadius: radiusL,
        buttonPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        outlinedButtonBorderWidth: 1.5,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackground: AppColors.darkBackground,
    );
  }

  // Typography Tokens
  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.8,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.4,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 20.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );
}
