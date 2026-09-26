import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../providers/font_provider.dart';

class ResponsiveUtils {
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getScaleFactor(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    final baseWidth = 440.0; // iPhone 16 Pro Max 기준

    // 최소/최대 스케일 제한
    double scale = screenWidth / baseWidth;

    // Android는 텍스트가 더 크게 보이므로 약간 작게 조정
    if (!kIsWeb && Platform.isAndroid) {
      scale *= 0.92; // Android에서 8% 작게
    }

    // 너무 작거나 크지 않도록 제한
    return scale.clamp(0.8, 1.2);
  }

  // 반응형 텍스트 크기
  /// 폰트 크기 = 기기 스케일 × 사용자 폰트 크기 설정(FontProvider)
  /// 설정 화면의 '폰트 크기'가 앱 전체에 반영되도록 배율을 여기 한 곳에서 적용한다.
  static double fontSize(BuildContext context, double baseSize) {
    return baseSize * getScaleFactor(context) * userFontScale(context);
  }

  /// 사용자가 설정한 폰트 배율 (기본 1.0 / +15% 1.15 / +30% 1.3)
  static double userFontScale(BuildContext context) {
    return Provider.of<FontProvider>(context, listen: true).fontScale;
  }

  // 반응형 패딩/마진
  static double spacing(BuildContext context, double baseSpacing) {
    return baseSpacing * getScaleFactor(context);
  }

  // 반응형 아이콘 크기
  static double iconSize(BuildContext context, double baseSize) {
    return baseSize * getScaleFactor(context);
  }

  // 기기별 텍스트 스타일 제공
  static TextStyle getTextStyle(
    BuildContext context, {
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'NotoSans',
      // fontSize()가 이미 사용자 폰트 배율을 포함한다 (중복 적용 금지)
      fontSize: ResponsiveUtils.fontSize(context, fontSize),
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

// 미리 정의된 반응형 텍스트 스타일들
class ResponsiveTextStyles {
  static TextStyle logoTitle(BuildContext context) =>
      ResponsiveUtils.getTextStyle(
        context,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1777CB),
        letterSpacing: 4,
      );
}
