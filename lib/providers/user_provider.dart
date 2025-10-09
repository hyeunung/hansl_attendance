import 'package:flutter/foundation.dart';

class UserProvider extends ChangeNotifier {
  String? _id;
  String? get id => _id;

  String? _name;
  String? get name => _name;

  String? _email;
  String? get email => _email;

  Map<String, dynamic>? _employee;
  Map<String, dynamic>? get employee => _employee;

  void setId(String? id) {
    _id = id;
    notifyListeners();
  }

  void setName(String? name) {
    _name = name;
    notifyListeners();
  }

  void setEmail(String? email) {
    _email = email;
    notifyListeners();
  }

  void setUser({
    required String id,
    required String name,
    required String email,
  }) {
    _id = id;
    _name = name;
    _email = email;
    notifyListeners();
  }

  void setEmployee(Map<String, dynamic>? employee) {
    _employee = employee;
    notifyListeners();
  }

  // 유저 정보 상태 및 관련 메서드 작성 예정
}
