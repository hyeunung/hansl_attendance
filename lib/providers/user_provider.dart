import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String? _name;
  String? get name => _name;

  String? _email;
  String? get email => _email;

  void setName(String? name) {
    _name = name;
    notifyListeners();
  }

  void setEmail(String? email) {
    _email = email;
    notifyListeners();
  }

  // 유저 정보 상태 및 관련 메서드 작성 예정
} 