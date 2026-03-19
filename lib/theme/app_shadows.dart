import 'package:flutter/material.dart';

/// Apple 스타일 옅은 그림자 시스템
class AppShadows {
  AppShadows._();

  // ─── Single Shadows ───
  static const BoxShadow xs = BoxShadow(
    color: Color(0x08000000), // 3% opacity
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  static const BoxShadow sm = BoxShadow(
    color: Color(0x0A000000), // 4% opacity
    blurRadius: 3,
    offset: Offset(0, 1),
  );

  static const BoxShadow md = BoxShadow(
    color: Color(0x0F000000), // 6% opacity
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  static const BoxShadow lg = BoxShadow(
    color: Color(0x12000000), // 7% opacity
    blurRadius: 6,
    offset: Offset(0, 3),
  );

  // ─── Legacy Aliases (기존 코드 호환) ───
  static const BoxShadow card = md;
  static BoxShadow get button => sm;
  static const BoxShadow light = xs;
  static const BoxShadow strong = lg;

  // ─── Shadow Lists ───
  static List<BoxShadow> cardShadow = [card];
  static List<BoxShadow> buttonShadow = [button];
  static List<BoxShadow> lightShadow = [light];
  static List<BoxShadow> strongShadow = [strong];

  // ─── New Apple-Style Lists ───
  static const List<BoxShadow> none = [];
  static const List<BoxShadow> xsShadow = [xs];
  static const List<BoxShadow> smShadow = [sm];
  static const List<BoxShadow> mdShadow = [md];
  static const List<BoxShadow> lgShadow = [lg];
}
