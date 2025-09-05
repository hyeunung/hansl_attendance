import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class AppTextTheme {
  static TextStyle title(BuildContext context) =>
      ResponsiveUtils.getTextStyle(context, fontSize: 20, fontWeight: FontWeight.bold);
}

class AppTextStyles {
  static TextStyle appBarTitle(BuildContext context) => ResponsiveUtils.getTextStyle(
    context,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  // Static text styles for widgets
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
}
