import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

/// 사유 입력 위젯
/// 휴가 신청 사유를 입력받는 재사용 가능한 컴포넌트
class LeaveMemoInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final int maxLines;
  final bool isRequired;
  final Function(String)? onChanged;
  final String? errorText;

  const LeaveMemoInputWidget({
    Key? key,
    required this.controller,
    this.focusNode,
    this.hintText = '사유를 입력하세요',
    this.maxLines = 3,
    this.isRequired = true,
    this.onChanged,
    this.errorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppShadows.card],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildInputField(),
          if (_shouldShowError()) _buildErrorMessage(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          '사유',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        if (isRequired)
          const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
        const Spacer(),
        if (controller.text.isNotEmpty)
          Text(
            '${controller.text.length}자',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _getBorderColor(), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 16, color: Color(0xFF222222)),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            errorText ?? '사유는 필수 입력 항목입니다.',
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor() {
    if (_shouldShowError()) {
      return Colors.red.withValues(alpha: 0.5);
    }
    if (controller.text.isNotEmpty) {
      return AppColors.primary.withValues(alpha: 0.3);
    }
    return Colors.transparent;
  }

  bool _shouldShowError() {
    return isRequired &&
        controller.text.trim().isEmpty &&
        (errorText != null || controller.text.isEmpty);
  }
}
