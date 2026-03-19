import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_shadows.dart';

/// Apple 스타일 재사용 가능한 데코레이션 시스템
class AppDecorations {
  AppDecorations._();

  // ─── Border Radius Constants ───
  static const double radiusXs = 6.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 100.0;

  // ─── Card Decorations ───
  static BoxDecoration card({
    Color? color,
    double radius = radiusMd,
    List<BoxShadow>? shadow,
    Border? border,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppShadows.mdShadow,
        border: border ?? Border.all(color: AppColors.borderLight, width: 0.5),
      );

  /// 기본 카드 (옅은 그림자 + 얇은 테두리)
  static BoxDecoration get defaultCard => card();

  /// 강조 카드
  static BoxDecoration get elevatedCard => card(shadow: AppShadows.lgShadow);

  /// 플랫 카드 (그림자 없음, 테두리만)
  static BoxDecoration get flatCard => card(
        shadow: AppShadows.none,
        border: Border.all(color: AppColors.border, width: 1),
      );

  // ─── Legacy Aliases (기존 코드 호환) ───
  static BoxDecoration whiteCard({double radius = 12}) => card(radius: radius);

  static BoxDecoration whiteCardNoShadow({double radius = 12}) =>
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration borderedCard({
    double radius = 12,
    Color borderColor = AppColors.border,
    double borderWidth = 1.0,
  }) =>
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      );

  static BoxDecoration coloredCard({
    required Color color,
    double radius = 12,
    bool hasShadow = false,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hasShadow ? AppShadows.mdShadow : null,
      );

  static BoxDecoration gradientBackground({
    List<Color>? colors,
    double radius = 0,
  }) =>
      BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
      );

  static BoxDecoration inputField({
    double radius = radiusSm,
    Color backgroundColor = AppColors.backgroundSecondary,
    Color borderColor = AppColors.border,
    bool hasBorder = true,
  }) =>
      BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: hasBorder ? Border.all(color: borderColor) : null,
      );

  static BoxDecoration selectedItem({
    double radius = radiusSm,
    Color color = AppColors.primary,
    double opacity = 0.1,
  }) =>
      BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      );

  // ─── Chip / Badge ───
  static BoxDecoration chip({
    required Color backgroundColor,
    double radius = radiusSm,
  }) =>
      BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration statusChip({
    required Color color,
    double radius = radiusXs,
    double opacity = 0.12,
  }) =>
      BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      );

  /// 상태별 칩 데코레이션
  static BoxDecoration statusBadge(String status) {
    Color bg;
    switch (status) {
      case 'approved':
        bg = AppColors.successLight;
        break;
      case 'pending':
        bg = AppColors.warningLight;
        break;
      case 'rejected':
        bg = AppColors.errorLight;
        break;
      default:
        bg = AppColors.gray100;
    }
    return chip(backgroundColor: bg);
  }

  /// 휴가 타입별 칩 데코레이션
  static BoxDecoration leaveTypeChip(String type) {
    final normalizedType = type.toLowerCase().replaceAll('_', '');
    Color bg;
    switch (normalizedType) {
      case 'annual':
      case 'halfam':
      case 'halfpm':
        bg = AppColors.annualLight;
        break;
      case 'biztrip':
      case 'businesstrip':
        bg = AppColors.biztripLight;
        break;
      case 'official':
        bg = AppColors.officialLight;
        break;
      default:
        bg = AppColors.infoLight;
    }
    return chip(backgroundColor: bg);
  }

  // ─── Button Decorations ───
  static BoxDecoration roundedButton({
    required Color color,
    double radius = radiusMd,
    bool hasShadow = true,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hasShadow ? AppShadows.smShadow : null,
      );

  static BoxDecoration primaryButton({double radius = radiusMd}) =>
      BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.smShadow,
      );

  static BoxDecoration secondaryButton({double radius = radiusMd}) =>
      BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
      );

  static BoxDecoration disabledButton({double radius = radiusMd}) =>
      BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(radius),
      );

  // ─── Section / Row ───
  static BoxDecoration sectionHeader({
    Color? color,
    double topRadius = radiusMd,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.backgroundSecondary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topRadius),
          topRight: Radius.circular(topRadius),
        ),
      );

  static BoxDecoration rowBackground({
    Color? color,
    double radius = radiusSm,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(radius),
      );

  // ─── Navigation ───
  static const BoxDecoration appBarBottom = BoxDecoration(
    color: Colors.white,
    border: Border(
      bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
    ),
  );

  static const BoxDecoration bottomNavBar = BoxDecoration(
    color: Colors.white,
    border: Border(
      top: BorderSide(color: AppColors.borderLight, width: 0.5),
    ),
  );
}
