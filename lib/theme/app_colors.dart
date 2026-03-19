import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Primary Brand ───
  static const Color primary = Color(0xFF1777CB);
  static const Color primaryLight = Color(0xFF1E90FF);
  static const Color primaryColor = Color(0xFF1777CB); // alias

  // 그라데이션 (레거시 호환 - 버튼 등에서 사용)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Gray Scale (Apple HIG 기반) ───
  static const Color gray50 = Color(0xFFFAFBFC);
  static const Color gray100 = Color(0xFFF5F6F8);
  static const Color gray150 = Color(0xFFF0F1F3);
  static const Color gray200 = Color(0xFFE9ECEF);
  static const Color gray300 = Color(0xFFDEE2E6);
  static const Color gray400 = Color(0xFFADB5BD);
  static const Color gray500 = Color(0xFF8E8E93);
  static const Color gray600 = Color(0xFF6C757D);
  static const Color gray700 = Color(0xFF495057);
  static const Color gray800 = Color(0xFF343A40);
  static const Color gray900 = Color(0xFF1A2332);
  static const Color gray950 = Color(0xFF0F1623);

  // ─── Semantic Text ───
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textDisabled = Color(0xFFADB5BD);

  // ─── Semantic Background ───
  static const Color backgroundPrimary = Color(0xFFFAFBFC);
  static const Color backgroundSecondary = Color(0xFFF5F6F8);
  static const Color backgroundTertiary = Color(0xFFFFFFFF);
  static const Color backgroundCard = Color(0xFFFFFFFF);

  // ─── Borders & Dividers ───
  static const Color border = Color(0xFFE9ECEF);
  static const Color borderLight = Color(0xFFF0F1F3);
  static const Color divider = Color(0xFFF0F1F3);

  // ─── Status Colors (차분한 Apple 톤) ───
  static const Color success = Color(0xFF34C759);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9500);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFFF3B30);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF007AFF);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ─── Functional Colors ───
  static const Color biztrip = Color(0xFF1976D2);
  static const Color biztripLight = Color(0xFFE3F2FD);
  static const Color annual = Color(0xFF34C759);
  static const Color annualLight = Color(0xFFE8F5E9);
  static const Color late_ = Color(0xFFE57373);
  static const Color lateLight = Color(0xFFFFEBEE);
  static const Color absent = Color(0xFFFF9500);
  static const Color absentLight = Color(0xFFFFF3E0);
  static const Color official = Color(0xFF8E8E93);
  static const Color officialLight = Color(0xFFF5F5F5);
  static const Color purple = Color(0xFF7E57C2);
  static const Color purpleLight = Color(0xFFF3E5F5);

  // ─── Calendar ───
  static const Color sunday = Color(0xFFFF3B30);
  static const Color saturday = Color(0xFF007AFF);
  static const Color weekday = Color(0xFF1C1C1E);
  static const Color holiday = Color(0xFFFF3B30);
  static const Color holidayBg = Color(0xFFFFE5E5);
}
