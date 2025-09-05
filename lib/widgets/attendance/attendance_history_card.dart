import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance.dart';

class AttendanceHistoryCard extends StatelessWidget {
  const AttendanceHistoryCard({super.key});

  Widget _buildHistoryRow(BuildContext context, AttendanceRecord record) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 12),
        vertical: ResponsiveUtils.spacing(context, 10),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: const Color(0xFF444444),
            ),
          ),
          Text(
            '출근: ${record.clockIn == null ? '-' : _formatTime(record.clockIn!)}',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: const Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 25)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
            boxShadow: [AppShadows.card],
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 2)),
                    child: Text('⏱️', style: ResponsiveUtils.getTextStyle(context, fontSize: 20)),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                  Text(
                    '최근 기록',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: const Color(0xFF343A40),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 15)),
              provider.recentHistory.isEmpty
                  ? Container(
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 20)),
                      alignment: Alignment.center,
                      child: Text(
                        '아직 기록이 없습니다',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          color: const Color(0xFF6C757D),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Column(
                      children: provider.recentHistory
                          .map(
                            (record) => Padding(
                              padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 8)),
                              child: _buildHistoryRow(context, record),
                            ),
                          )
                          .toList(),
                    ),
            ],
          ),
        );
      },
    );
  }
}
