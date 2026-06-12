import 'package:flutter/material.dart';

class AppColors {
  // Primary dark marine bases
  static const Color deepNavy = Color(0xFF030C1B);
  static const Color oceanNavy = Color(0xFF0A192F);
  static const Color cardNavy = Color(0xFF112240);

  // Core thematic accents
  static const Color oceanBlue = Color(0xFF0077B6);
  static const Color skyBlue = Color(0xFF00B4D8);
  static const Color aquamarine = Color(0xFF00F5D4);

  // Status and feedback indicators
  static const Color crimsonAlert = Color(0xFFD90429);
  static const Color warnings = Color(0xFFFFB703);
  static const Color safetyGreen = Color(0xFF2EC4B6);

  // Light-to-dark contrast markers
  static const Color textWhite = Color(0xFFF8F9FA);
  static const Color textMuted = Color(0xFF8892B0);
  static const Color sunlightHighContrast = Color(0xFFFFFFFF);

  // Gradient definitions
  static const LinearGradient marineGradient = LinearGradient(
    colors: [deepNavy, oceanNavy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient activeAlertGradient = LinearGradient(
    colors: [crimsonAlert, Color(0xFFEF233C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [oceanBlue, aquamarine],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
