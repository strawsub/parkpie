/// Standardized spacing constants following 8pt grid system.
/// Use these instead of magic numbers in EdgeInsets/SizedBox.
class Spacing {
  // Base spacing scale (multiples of 4)
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 60.0;

  // Semantic spacing
  static const double cardPadding = md; // 16
  static const double screenPadding = xl; // 24
  static const double buttonPadding = md; // 16
  static const double listItemSpacing = xs; // 8
  static const double sectionSpacing = xl; // 24
}

/// Standardized border radius values.
class Radii {
  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double round = 999.0; // For pill-shaped buttons

  // Semantic radii
  static const double card = md; // 12
  static const double button = md; // 12
  static const double chip = lg; // 16
  static const double modal = xxl; // 24
}

/// Minimum touch target sizes (accessibility).
class TouchTargets {
  static const double minimum = 48.0; // WCAG AAA minimum
  static const double comfortable = 56.0; // Comfortable tap target
}
