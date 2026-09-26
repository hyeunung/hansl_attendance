import 'package:flutter/material.dart';
import '../../models/leave_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';

/// 연차 유형 선택 드롭다운 위젯
/// 연차, 반차, 공가 등을 선택할 수 있는 재사용 가능한 컴포넌트
class LeaveTypeSelectorWidget extends StatefulWidget {
  final LeaveType? selectedType;
  final Function(LeaveType?) onTypeChanged;
  final List<LeaveType> availableTypes;

  const LeaveTypeSelectorWidget({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    this.availableTypes = const [
      LeaveType.annual,
      LeaveType.halfAm,
      LeaveType.halfPm,
      LeaveType.official,
    ],
  });

  @override
  State<LeaveTypeSelectorWidget> createState() =>
      _LeaveTypeSelectorWidgetState();
}

class _LeaveTypeSelectorWidgetState extends State<LeaveTypeSelectorWidget> {
  bool _dropdownOpen = false;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlatCardHeader(
            title: '휴가 종류',
            icon: Icons.category_outlined,
            iconColor: AppColors.primary,
          ),
          _buildSelectedRow(context),
          _buildOptionList(context),
        ],
      ),
    );
  }

  /// 현재 선택값 + 펼치기 토글
  Widget _buildSelectedRow(BuildContext context) {
    final hasValue = widget.selectedType != null;

    return InkWell(
      onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 14),
          vertical: ResponsiveUtils.spacing(context, 9),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _dropdownOpen
                  ? AppColors.borderLight
                  : Colors.transparent,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (hasValue) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getTypeColor(widget.selectedType!),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
            ],
            Expanded(
              child: Text(
                widget.selectedType?.label ?? '휴가 종류를 선택하세요',
                style: hasValue
                    ? AppTextStyles.tableCell(context)
                    : AppTextStyles.tableCell(
                        context,
                        color: AppColors.textDisabled,
                      ),
              ),
            ),
            Icon(
              _dropdownOpen ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  /// 선택 가능한 유형 목록 (펼쳤을 때만 노출)
  Widget _buildOptionList(BuildContext context) {
    final rowHeight = ResponsiveUtils.spacing(context, 38);

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      child: SizedBox(
        height: _dropdownOpen ? widget.availableTypes.length * rowHeight : 0,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: widget.availableTypes
              .map((type) => _buildOptionRow(context, type, rowHeight))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildOptionRow(BuildContext context, LeaveType type, double height) {
    final isSelected = widget.selectedType == type;
    final typeColor = _getTypeColor(type);

    return InkWell(
      onTap: () {
        widget.onTypeChanged(type);
        setState(() => _dropdownOpen = false);
      },
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 14),
        ),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: typeColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: ResponsiveUtils.spacing(context, 8)),
            Text(
              type.label,
              style: AppTextStyles.tableCell(
                context,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (type.days > 0)
              StatusChip(
                label: '${FlatProgressRow.formatCount(type.days)}일',
                color: typeColor,
              ),
            if (isSelected) ...[
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Icon(Icons.check, size: 16, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return AppColors.info;
      case LeaveType.halfAm:
        return AppColors.warning;
      case LeaveType.halfPm:
        return AppColors.success;
      case LeaveType.official:
        return AppColors.textTertiary;
      default:
        return AppColors.textPrimary;
    }
  }
}
