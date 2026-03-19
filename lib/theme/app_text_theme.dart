import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import 'app_colors.dart';

class AppTextTheme {
  static TextStyle title(BuildContext context) => ResponsiveUtils.getTextStyle(
    context,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
}

/// AppBar 타이틀에 로고 + 텍스트
class AppBarTitle extends StatelessWidget {
  final String title;
  const AppBarTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icons/icon_40.png',
          width: 34,
          height: 34,
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.appBarTitle(context)),
      ],
    );
  }
}

class AppTextStyles {
  AppTextStyles._();

  // ─── AppBar (Apple 스타일: 다크 텍스트) ───
  static TextStyle appBarTitle(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // ─── Section Headers ───
  static TextStyle sectionTitle(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle sectionSubtitle(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  // ─── Card Content ───
  static TextStyle cardTitle(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle cardBody(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle cardCaption(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
      );

  // ─── Status / Chip ───
  static TextStyle chipLabel(BuildContext context, {Color? color}) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textSecondary,
        letterSpacing: 0.1,
      );

  static TextStyle statusLabel(BuildContext context, String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = AppColors.success;
        break;
      case 'pending':
        color = AppColors.warning;
        break;
      case 'rejected':
        color = AppColors.error;
        break;
      default:
        color = AppColors.textTertiary;
    }
    return ResponsiveUtils.getTextStyle(
      context,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.1,
    );
  }

  // ─── Button ───
  static TextStyle buttonPrimary(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle buttonSecondary(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      );

  // ─── Data / Numbers ───
  static TextStyle statNumber(BuildContext context, {Color? color}) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        height: 1.0,
        letterSpacing: -0.5,
      );

  static TextStyle statLabel(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      );

  // ─── Compact (small labels, stat grid) ───
  static TextStyle compactLabel(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      );

  static TextStyle compactValue(BuildContext context, {Color? color}) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle chipSmall(BuildContext context, {Color? color}) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textSecondary,
      );

  // ─── Table ───
  static TextStyle tableHeader(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      );

  static TextStyle tableCell(BuildContext context, {Color? color}) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle tableCellSub(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  // ─── Section / List ───
  static TextStyle sectionHeader(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle listTitle(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle listSubtitle(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
      );

  // ─── Input / Empty ───
  static TextStyle inputLabel(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle emptyState(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
      );

  // ─── Static Styles (legacy) ───
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
