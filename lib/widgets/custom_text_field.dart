import 'package:flutter/material.dart';

// 여러 화면에서 재사용 가능한 커스텀 입력창 위젯
class CustomTextField extends StatelessWidget {
  final String hintText; // 입력창에 표시할 힌트 텍스트
  final TextEditingController? controller; // 입력값을 제어하는 컨트롤러
  final bool obscureText; // 비밀번호 입력 등 텍스트 숨김 여부

  const CustomTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    // TextField 위젯을 사용해 입력창을 만듦
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(hintText: hintText, border: const OutlineInputBorder()),
    );
  }
}
