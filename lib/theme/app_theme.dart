import 'package:flutter/material.dart';
import 'app_colors.dart';

// 앱 전체에 적용되는 테마(색상, 폰트 등) 설정 클래스
class AppTheme {
  // 밝은 테마 설정 (Material3, 메인 컬러, 폰트 등)
  static ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    fontFamily: 'NotoSans',
    useMaterial3: true,
  );
}
