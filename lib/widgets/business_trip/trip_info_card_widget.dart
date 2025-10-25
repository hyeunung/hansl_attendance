import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';

/// 출장 정보 카드 위젯
/// 이번 달/올해 출장 현황을 표시하는 위젯
class TripInfoCardWidget extends StatelessWidget {
  final int monthTrips;
  final int yearTrips;
  final int currentMonth;
  final int currentYear;

  const TripInfoCardWidget({
    super.key,
    required this.monthTrips,
    required this.yearTrips,
    required this.currentMonth,
    required this.currentYear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          _buildMainInfo(context),
          const SizedBox(height: 16),
          _buildYearInfo(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_getMonthName(currentMonth)} 출장',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        _buildTripIndicator(context),
      ],
    );
  }

  Widget _buildTripIndicator(BuildContext context) {
    final frequency = _getTripFrequency();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getFrequencyColor(frequency).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_getFrequencyIcon(frequency), color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            frequency,
            style: ResponsiveUtils.getTextStyle(
              context,
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getTripFrequency() {
    if (monthTrips == 0) return '없음';
    if (monthTrips <= 2) return '보통';
    if (monthTrips <= 4) return '많음';
    return '매우 많음';
  }

  Color _getFrequencyColor(String frequency) {
    switch (frequency) {
      case '없음':
        return Colors.green;
      case '보통':
        return Colors.blue;
      case '많음':
        return Colors.orange;
      case '매우 많음':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  IconData _getFrequencyIcon(String frequency) {
    switch (frequency) {
      case '없음':
        return Icons.home;
      case '보통':
        return Icons.directions_car;
      case '많음':
        return Icons.flight_takeoff;
      case '매우 많음':
        return Icons.rocket_launch;
      default:
        return Icons.info;
    }
  }

  Widget _buildMainInfo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [_buildMonthProgress(context), _buildMainCount(context)],
    );
  }

  Widget _buildMonthProgress(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '월간 진행률',
          style: ResponsiveUtils.getTextStyle(
            context,
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 120,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (monthTrips / 10).clamp(0.0, 1.0), // 월 10회 기준
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(monthTrips / 10 * 100).toInt()}%',
          style: ResponsiveUtils.getTextStyle(
            context,
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMainCount(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              monthTrips.toString(),
              style: ResponsiveUtils.getTextStyle(
                context,
                fontWeight: FontWeight.w900,
                fontSize: 48,
                color: Colors.white,
                height: 1,
              ),
            ),
            Text(
              '회',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          '이번 달 출장',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildYearInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$currentYear년 누적',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$yearTrips회',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildYearTrend(context),
                  ],
                ),
              ],
            ),
          ),
          _buildYearStats(context),
        ],
      ),
    );
  }

  Widget _buildYearTrend(BuildContext context) {
    final avgMonthly = yearTrips / currentMonth;
    final trend = avgMonthly > 3
        ? '상승'
        : avgMonthly > 1
        ? '보통'
        : '하락';
    final trendIcon = trend == '상승'
        ? Icons.trending_up
        : trend == '보통'
        ? Icons.trending_flat
        : Icons.trending_down;
    final trendColor = trend == '상승'
        ? Colors.red
        : trend == '보통'
        ? Colors.yellow
        : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(trendIcon, color: Colors.white, size: 14),
          const SizedBox(width: 2),
          Text(
            trend,
            style: ResponsiveUtils.getTextStyle(
              context,
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearStats(BuildContext context) {
    final avgMonthly = yearTrips / currentMonth;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '월평균',
            style: ResponsiveUtils.getTextStyle(
              context,
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
          Text(
            avgMonthly.toStringAsFixed(1),
            style: ResponsiveUtils.getTextStyle(
              context,
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      '1월',
      '2월',
      '3월',
      '4월',
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
      '11월',
      '12월',
    ];
    return months[month - 1];
  }
}
