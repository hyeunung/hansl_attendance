import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';

/// 연차 정보를 표시하는 카드 위젯
/// 남은 연차, 사용 연차, 부여 연차 등의 정보를 시각적으로 표현
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          _buildMainInfo(context),
          const SizedBox(height: 16),
          _buildYearlyInfo(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '신청 가능',
            style: AppTextStyles.inputLabel(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        _buildUsedIndicator(context),
      ],
    );
  }

  Widget _buildUsedIndicator(BuildContext context) {
    final double usedPercentage = grantedAnnual > 0
        ? (usedAnnual / grantedAnnual * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getUsedColor(usedPercentage).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '사용률 ${usedPercentage.toStringAsFixed(0)}%',
        style: AppTextStyles.statLabel(context).copyWith(
          fontSize: ResponsiveUtils.fontSize(context, 12),
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getUsedColor(double percentage) {
    if (percentage < 50) return Colors.green;
    if (percentage < 80) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMainInfo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '사용: ${_formatDays(usedAnnual)}일',
              style: AppTextStyles.inputLabel(context).copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 4,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: grantedAnnual > 0
                    ? (usedAnnual / grantedAnnual).clamp(0.0, 1.0)
                    : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatDays(remainAnnual),
                  style: AppTextStyles.statNumber(context, color: Colors.white).copyWith(
                    fontSize: ResponsiveUtils.fontSize(context, 40),
                  ),
                ),
                Text(
                  '일',
                  style: AppTextStyles.sectionTitle(context).copyWith(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.fontSize(context, 24),
                  ),
                ),
              ],
            ),
            Text(
              '/ ${_formatDays(grantedAnnual)}일',
              style: AppTextStyles.sectionSubtitle(context).copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearlyInfo(BuildContext context) {
    return Column(
      children: [
        _buildYearRow(context, currentYear, currentYearGranted, true),
        const SizedBox(height: 4),
        _buildYearRow(context, nextYear, nextYearGranted, false),
      ],
    );
  }

  Widget _buildYearRow(BuildContext context, int year, double granted, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isCurrent ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Text(
            '$year.01.01 ~ $year.12.31',
            style: AppTextStyles.inputLabel(context).copyWith(
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_formatDays(granted)}일',
              style: AppTextStyles.inputLabel(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  String _formatDays(double days) {
    return days % 1 == 0 ? days.toInt().toString() : days.toString();
  }
}
