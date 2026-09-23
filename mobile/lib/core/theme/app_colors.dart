import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette
  static const Color primaryEmergencyRed = Color(0xFFFF3B30);
  static const Color deepEmergencyRed = Color(0xFFD32F2F);
  static const Color warmSignalAmber = Color(0xFFFF9500);
  static const Color safeEmerald = Color(0xFF34C759);
  static const Color deepCharcoal = Color(0xFF1C1C1E);
  static const Color offWhite = Color(0xFFF2F2F7);

  // Surface & Neutral (Light)
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E5EA);
  static const Color lightTextPrimary = Color(0xFF1C1C1E);
  static const Color lightTextSecondary = Color(0xFF8E8E93);

  // Surface & Neutral (Dark)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkCard = Color(0xFF2C2C2E);
  static const Color darkBorder = Color(0xFF38383A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);

  // Severity Colors
  static const Color severityCritical = Color(0xFFFF3B30);
  static const Color severityHigh = Color(0xFFFF9500);
  static const Color severityModerate = Color(0xFFFFCC00);
  static const Color severityLow = Color(0xFF34C759);

  // Status Colors
  static const Color statusLive = Color(0xFFFF3B30);
  static const Color statusVerified = Color(0xFF007AFF);
  static const Color statusResponding = Color(0xFFFF9500);
  static const Color statusResolved = Color(0xFF34C759);
}
