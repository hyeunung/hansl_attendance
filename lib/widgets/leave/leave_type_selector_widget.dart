import 'package:flutter/material.dart';
import '../../models/leave_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';

/// 연차 유형 선택 드롭다운 위젯
/// 연차, 반차, 공가 등을 선택할 수 있는 재사용 가능한 컴포넌트
class LeaveTypeSelectorWidget extends StatefulWidget {
  final LeaveType selectedType;
  final Function(LeaveType) onTypeChanged;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.cardShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.selectedType.label,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  _dropdownOpen ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _dropdownOpen ? (widget.availableTypes.length * 48.0) : 0,
          curve: Curves.easeInOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: widget.availableTypes.map((type) {
                return Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () {
                      widget.onTypeChanged(type);
                      setState(() {
                        _dropdownOpen = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.selectedType == type
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: _getTypeColor(type),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            type.label,
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 18,
                              fontWeight: widget.selectedType == type
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: widget.selectedType == type
                                  ? AppColors.primary
                                  : Colors.black87,
                            ),
                          ),
                          if (type.days > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(
                                  type,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${type.days}일',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getTypeColor(type),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return const Color(0xFF4A90E2); // 파랑
      case LeaveType.halfAm:
        return const Color(0xFFF5A623); // 주황
      case LeaveType.halfPm:
        return const Color(0xFF7ED321); // 초록
      case LeaveType.official:
        return const Color(0xFF9B9B9B); // 회색
      default:
        return Colors.black;
    }
  }
}
