import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역 폰트 크기 설정
///
/// 기본(100%)에서 +10% / +20% / +30% / +35% 까지 5단계.
class FontProvider extends ChangeNotifier {
  static const String defaultSize = '기본';

  /// 작은 값 → 큰 값 순서 (슬라이더 눈금 순서와 동일)
  static const List<String> options = [
    defaultSize,
    '+10%',
    '+20%',
    '+30%',
    '+35%',
  ];

  /// 구버전에서 저장된 값 → 현재 옵션 매핑
  static const Map<String, String> _legacyValues = {
    '+15%': '+20%',
    '작게': defaultSize,
    '크게': '+10%',
    '가장 크게': '+30%',
    '보통': defaultSize,
    '0% (기본)': defaultSize,
  };

  String _fontSize = defaultSize;

  FontProvider() {
    loadFontSize();
  }

  String get fontSize => _fontSize;

  double get fontScale => scaleOf(_fontSize);

  /// 옵션 문자열에 해당하는 배율
  static double scaleOf(String size) {
    switch (size) {
      case '+10%':
        return 1.10;
      case '+20%':
        return 1.20;
      case '+30%':
        return 1.30;
      case '+35%':
        return 1.35;
      default:
        return 1.0; // 기본
    }
  }

  Future<void> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('font_size');

    if (saved != null && options.contains(saved)) {
      _fontSize = saved;
    } else if (saved != null && _legacyValues.containsKey(saved)) {
      // 구버전 값은 대응되는 현재 옵션으로 옮겨 저장한다
      _fontSize = _legacyValues[saved]!;
      await prefs.setString('font_size', _fontSize);
    } else {
      _fontSize = defaultSize;
      if (saved != null) {
        await prefs.setString('font_size', defaultSize);
      }
    }
    notifyListeners();
  }

  /// 저장하지 않고 화면에만 적용 (다이얼로그 미리보기용)
  /// 확정은 [setFontSize], 되돌리기는 이전 값으로 다시 호출한다.
  void previewFontSize(String size) {
    if (_fontSize == size || !options.contains(size)) return;
    _fontSize = size;
    notifyListeners();
  }

  Future<void> setFontSize(String size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size', size);
    notifyListeners();
  }
}
