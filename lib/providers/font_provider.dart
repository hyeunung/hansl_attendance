import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider extends ChangeNotifier {
  String _fontSize = '0% (기본)';

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
        return 1.0; // 0% (기본)
    }
  }

  Future<void> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getString('font_size') ?? '0% (기본)';
    notifyListeners();
  }

  Future<void> setFontSize(String size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size', size);
    notifyListeners();
  }
}
