import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider extends ChangeNotifier {
  /// 지원하는 폰트 크기 옵션 (저장값과 표시 라벨이 동일)
  static const String defaultSize = '기본';
  static const List<String> options = [defaultSize, '+15%', '+30%'];

  String _fontSize = defaultSize;

  FontProvider() {
    loadFontSize();
  }

  String get fontSize => _fontSize;

  double get fontScale {
    switch (_fontSize) {
      case '+15%':
        return 1.15;
      case '+30%':
        return 1.3;
      default:
        return 1.0; // 기본
    }
  }

  Future<void> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('font_size');
    // 구버전에서 저장된 값('보통', '0% (기본)' 등)은 기본값으로 정리
    if (saved != null && options.contains(saved)) {
      _fontSize = saved;
    } else {
      _fontSize = defaultSize;
      if (saved != null) {
        await prefs.setString('font_size', defaultSize);
      }
    }
    notifyListeners();
  }

  Future<void> setFontSize(String size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size', size);
    notifyListeners();
  }
}
