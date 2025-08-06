import 'package:flutter/material.dart';

class AppShadows {
  static const BoxShadow card = BoxShadow(
    color: Color(0x1A000000), // 검정, 10% opacity
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static BoxShadow get button => BoxShadow(
    color: Colors.black.withValues(alpha: 0.36),
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  static const BoxShadow light = BoxShadow(
    color: Color(0x0D000000), // 검정, 5% opacity
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  static const BoxShadow strong = BoxShadow(
    color: Color(0x33000000), // 검정, 20% opacity
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  // 여러 그림자 조합이 필요할 때 리스트로도 제공
  static List<BoxShadow> cardShadow = [card];
  static List<BoxShadow> buttonShadow = [button];
  static List<BoxShadow> lightShadow = [light];
  static List<BoxShadow> strongShadow = [strong];
} 