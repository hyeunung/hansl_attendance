import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider extends ChangeNotifier {
  String _fontSize = '보통';
  
  FontProvider() {
    loadFontSize();
  }
  
  String get fontSize => _fontSize;
  
  double get fontScale {
    switch (_fontSize) {
      case '작게':
        return 0.85;
      case '크게':
        return 1.15;
      default:
        return 1.0; // 보통
    }
  }
  
  Future<void> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getString('font_size') ?? '보통';
    notifyListeners();
  }
  
  Future<void> setFontSize(String size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size', size);
    notifyListeners();
  }
} 