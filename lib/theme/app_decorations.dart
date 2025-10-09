import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_shadows.dart';

/// 공통으로 사용되는 BoxDecoration 모음
class AppDecorations {
  // 기본 흰색 카드
  static BoxDecoration whiteCard({double radius = 14}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [AppShadows.card],
    );
  }
  
  // 그림자 없는 흰색 카드
  static BoxDecoration whiteCardNoShadow({double radius = 14}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    );
  }
  
  // 테두리가 있는 카드
  static BoxDecoration borderedCard({
    double radius = 14,
    Color borderColor = const Color(0xFFE0E0E0),
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor,
        width: borderWidth,
      ),
    );
  }
  
  // 배경색이 있는 카드
  static BoxDecoration coloredCard({
    required Color color,
    double radius = 14,
    bool hasShadow = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: hasShadow ? [AppShadows.card] : null,
    );
  }
  
  // 그라디언트 배경
  static BoxDecoration gradientBackground({
    List<Color>? colors,
    double radius = 0,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors ?? [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
    );
  }
  
  // 입력 필드 데코레이션
  static BoxDecoration inputField({
    double radius = 10,
    Color backgroundColor = const Color(0xFFF8F9FA),
    Color borderColor = const Color(0xFFE0E0E0),
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: hasBorder ? Border.all(color: borderColor) : null,
    );
  }
  
  // 선택된 아이템 데코레이션
  static BoxDecoration selectedItem({
    double radius = 10,
    Color color = AppColors.primary,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    );
  }
  
  // 상태 칩 데코레이션 (승인, 대기, 반려 등)
  static BoxDecoration statusChip({
    required Color color,
    double radius = 8,
    double opacity = 0.12,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
    );
  }
  
  // 둥근 버튼 데코레이션
  static BoxDecoration roundedButton({
    required Color color,
    double radius = 8,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: hasShadow ? [AppShadows.button] : null,
    );
  }
}