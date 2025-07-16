import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class AppTextTheme {
  static TextStyle title(BuildContext context) => ResponsiveUtils.getTextStyle(
    context,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
} 

class AppTextStyles {
  static TextStyle appBarTitle(BuildContext context) => ResponsiveUtils.getTextStyle(
    context,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
} 