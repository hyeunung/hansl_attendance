import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';

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
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '사유를 입력하세요',
    this.maxLines = 3,
    this.isRequired = true,
    this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlatCardHeader(
            title: isRequired ? '사유 *' : '사유',
            icon: Icons.edit_note,
            iconColor: AppColors.primary,
            trailing: controller.text.isNotEmpty
                ? Text(
                    '${controller.text.length}자',
                    style: AppTextStyles.listSubtitle(context),
                  )
                : null,
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 14),
              vertical: ResponsiveUtils.spacing(context, 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(context),
                if (_shouldShowError()) _buildErrorMessage(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(BuildContext context) {
    return Container(
      decoration: AppDecorations.inputField(
        borderColor: _getBorderColor(),
        hasBorder: _shouldShowError() || controller.text.isNotEmpty,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.cardBody(context).copyWith(
            color: AppColors.textDisabled,
          ),
          // 바깥 Container가 테두리를 그리므로 전역 채움/테두리는 끈다
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: maxLines,
        onChanged: onChanged,
        style: AppTextStyles.tableCell(context).copyWith(
          fontSize: ResponsiveUtils.fontSize(context, 13),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 4),
          Text(
            errorText ?? '사유는 필수 입력 항목입니다.',
            style: AppTextStyles.listSubtitle(context).copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor() {
    if (_shouldShowError()) {
      return AppColors.error.withValues(alpha: 0.5);
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
