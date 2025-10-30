import 'package:flutter/material.dart';

/// Centralized color palette for ParkPie app.
/// Replace all inline Color(0x...) literals with these constants.
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF7FAC58);
  static const Color primaryLight = Color(0xFFE8F3DD);
  static const Color primaryDark = Color(0xFF5A8642);

  // Semantic colors
  static const Color error = Color(0xFFFF4757);
  static const Color errorLight = Color(0x1AFF4757); // 10% opacity
  static const Color errorBorder = Color(0x4DFF4757); // 30% opacity
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFE65100); // Orange 900
  static const Color info = Color(0xFF2196F3);

  // Neutral colors (text, borders, backgrounds)
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF757575); // grey.shade600
  static const Color textTertiary = Color(0xFF9E9E9E); // grey.shade400
  static const Color textDisabled = Color(0xFFBDBDBD); // grey.shade400

  static const Color border = Color(0xFFE0E0E0); // grey.shade300
  static const Color borderLight = Color(0xFFF5F5F5); // grey.shade100

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F5F5); // grey.shade50
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Opacity variants
  static final Color shadow = Colors.black.withValues(alpha: 0.3);
  static final Color shadowLight = Colors.black.withValues(alpha: 0.1);
  static final Color overlay = Colors.black.withValues(alpha: 0.5);
  static final Color overlayLight = Colors.black.withValues(alpha: 0.35);
  static final Color scrim = Colors.black.withValues(alpha: 0.04);

  // Special colors for specific components
  static const Color timerOvertime = error;
  static const Color timerActive = primary;
  static const Color cameraOverlay = Colors.black;
}
