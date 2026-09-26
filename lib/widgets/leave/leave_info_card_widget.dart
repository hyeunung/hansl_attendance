import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../shared/flat_section.dart';

/// 연차 정보를 표시하는 카드 위젯
/// 잔여/사용/부여 연차와 연도별 부여 현황을 표시
class LeaveInfoCardWidget extends StatelessWidget {
  final double remainAnnual;
  final double grantedAnnual;
  final double usedAnnual;
  final int currentYear;
  final int nextYear;
  final double currentYearGranted;
  final double nextYearGranted;

  const LeaveInfoCardWidget({
    super.key,
    required this.remainAnnual,
    required this.grantedAnnual,
    required this.usedAnnual,
    required this.currentYear,
    required this.nextYear,
    required this.currentYearGranted,
    required this.nextYearGranted,
  });

  @override
  Widget build(BuildContext context) {
    final usedPercentage = grantedAnnual > 0
        ? (usedAnnual / grantedAnnual * 100).round()
        : 0;

    return FlatCard(
      child: Column(
        children: [
          FlatCardHeader(
            title: '내 연차 현황',
            icon: Icons.event_available,
            iconColor: AppColors.primary,
            trailing: const StatusChip(
              label: '신청 가능',
              color: AppColors.success,
            ),
          ),
          FlatStatGrid(
            items: [
              FlatStatItem(
                label: '잔여',
                value: '${_formatDays(remainAnnual)}일',
                color: AppColors.primary,
              ),
              FlatStatItem(
                label: '사용',
                value: '${_formatDays(usedAnnual)}일',
              ),
              FlatStatItem(
                label: '총 부여',
                value: '${_formatDays(grantedAnnual)}일',
              ),
            ],
          ),
          FlatProgressRow(
            label: '사용률',
            completed: usedAnnual,
            total: grantedAnnual,
            percentage: usedPercentage,
            color: AppColors.primary,
            valueText:
                '${_formatDays(usedAnnual)}일 / ${_formatDays(grantedAnnual)}일',
          ),
          FlatInfoRow(
            label: '$currentYear년',
            value: '$currentYear.01.01 ~ $currentYear.12.31',
            trailing: StatusChip(
              label: '${_formatDays(currentYearGranted)}일',
              color: AppColors.info,
            ),
          ),
          FlatInfoRow(
            label: '$nextYear년',
            value: '$nextYear.01.01 ~ $nextYear.12.31',
            trailing: StatusChip(
              label: '${_formatDays(nextYearGranted)}일',
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDays(double days) {
    return days % 1 == 0 ? days.toInt().toString() : days.toString();
  }
}
