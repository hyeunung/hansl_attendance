import 'package:flutter/material.dart';

// 여러 화면에서 재사용 가능한 커스텀 버튼 위젯
class CustomButton extends StatelessWidget {
  final String text; // 버튼에 표시할 텍스트
  final VoidCallback onPressed; // 버튼 클릭 시 실행할 함수

  const CustomButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // ElevatedButton을 사용해 버튼을 만듦
    return ElevatedButton(onPressed: onPressed, child: Text(text));
  }
}
