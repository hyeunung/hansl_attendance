import 'package:flutter/material.dart';

class AppShadows {
  static const BoxShadow card = BoxShadow(
    color: Color(0x1A000000), // 검정, 10% opacity
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static const BoxShadow button = BoxShadow(
    color: Color(0x14000000), // 검정, 8% opacity
    blurRadius: 10,
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
  static const List<BoxShadow> cardShadow = [card];
  static const List<BoxShadow> buttonShadow = [button];
  static const List<BoxShadow> lightShadow = [light];
  static const List<BoxShadow> strongShadow = [strong];
} 