import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildMainInfo(),
          const SizedBox(height: 16),
          _buildYearlyInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '신청 가능',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        _buildUsedIndicator(),
      ],
    );
  }

  Widget _buildUsedIndicator() {
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
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
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

  Widget _buildMainInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '사용: ${_formatDays(usedAnnual)}일',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const Text(
                  '일',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              '/ ${_formatDays(grantedAnnual)}일',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearlyInfo() {
    return Column(
      children: [
        _buildYearRow(currentYear, currentYearGranted, true),
        const SizedBox(height: 4),
        _buildYearRow(nextYear, nextYearGranted, false),
      ],
    );
  }

  Widget _buildYearRow(int year, double granted, bool isCurrent) {
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
            style: const TextStyle(color: Colors.white, fontSize: 14),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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
