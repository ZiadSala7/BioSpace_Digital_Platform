import 'package:flutter/material.dart';

/// App Colors - BioSpace Egypt Brand Palette
class AppColors {
  AppColors._();

  // Base colors
  static const Color background = Color(0xFFF9F5F6); // Off White
  static const Color foreground = Color(0xFF1A1A1A); // Near Black
  static const Color card = Color(0xFFFFFFFF); // Pure White
  static const Color cardForeground = Color(0xFF1A1A1A); // Near Black

  // Primary colors (Burgundy)
  static const Color primary = Color(0xFF6B1A38); // Burgundy
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFF4A0F27); // Primary Dark
  static const Color primaryLight = Color(0xFF8C2147); // Deep Rose

  // Secondary colors (Gold accent)
  static const Color secondary = Color(0xFFC4873A); // Gold
  static const Color secondaryForeground = Color(0xFF1A1A1A);
  static const Color secondaryLight = Color(0xFFDFAB6E); // Gold Light

  // Muted colors (Blush tones)
  static const Color muted = Color(0xFFE8C5D0); // Soft Rose
  static const Color mutedForeground = Color(0xFF555555); // Charcoal

  // Accent colors (Midnight Blue)
  static const Color accent = Color(0xFF3A4A6B); // Midnight Blue
  static const Color accentForeground = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1A1A1A); // Near Black

  // Border & Input
  static const Color border = Color(0xFFE8C5D0); // Soft Rose
  static const Color input = Color(0xFFFFFFFF);
  static const Color ring = Color(0xFF6B1A38); // Burgundy

  // Custom app colors
  static const Color beige = Color(0xFFF9F5F6); // Off White
  static const Color beigeDark = Color(0xFFF5E8ED); // Blush
  static const Color orange = Color(0xFFC4873A); // Gold
  static const Color orangeLight = Color(0xFFDFAB6E); // Gold Light
  static const Color purple = primary; // Legacy alias
  static const Color purpleLight = primaryLight; // Legacy alias
  static const Color purpleDark = primaryDark; // Legacy alias
  static const Color dark = Color(0xFF1A1A1A); // Near Black
  static const Color lavender = Color(0xFFC4768F); // Muted Rose
  static const Color lavenderLight = Color(0xFFF5E8ED); // Blush

  // Semantic colors
  static const Color destructive = Color(0xFFDC2626);
  static const Color destructiveForeground = Color(0xFFDC2626);
  static const Color success = Color(0xFF2C6B5A); // Deep Teal
  static const Color warning = Color(0xFFC4873A); // Gold
  static const Color info = Color(0xFF3A4A6B); // Midnight Blue

  // Bottom navigation
  static const Color bottomNavBackground = Color(0xFF1A1A1A);
  static const Color bottomNavActive = Color(0xFFFFFFFF);
  static const Color bottomNavInactive = Color(0xFF555555); // Charcoal

  // Overlay colors
  static const Color whiteOverlay20 = Color(0x33FFFFFF);
  static const Color whiteOverlay40 = Color(0x66FFFFFF);
  static const Color whiteOverlay10 = Color(0x1AFFFFFF);
  static const Color blackOverlay20 = Color(0x33000000);
}
