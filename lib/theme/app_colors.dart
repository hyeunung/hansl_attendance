import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1777CB); // 메인 컬러
  static const Color primaryLight = Color(0xFF1E90FF); // 그라데이션용 밝은 색상
  static const Color primaryColor = Color(
    0xFF1777CB,
  ); // primaryColor alias for compatibility

  // 그라데이션 정의
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  // 필요시 추가 컬러 정의
}
