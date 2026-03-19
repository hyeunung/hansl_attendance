import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance.dart';

class AttendanceHistoryCard extends StatelessWidget {
  const AttendanceHistoryCard({super.key});

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: AppDecorations.defaultCard,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 섹션 헤더
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 16),
                  vertical: ResponsiveUtils.spacing(context, 10),
                ),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
                ),
                child: Text(
                  '최근 기록',
                  style: AppTextStyles.sectionHeader(context).copyWith(fontSize: 14),
                ),
              ),

              // 테이블 헤더
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 16),
                  vertical: ResponsiveUtils.spacing(context, 8),
                ),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '날짜',
                        style: AppTextStyles.tableHeader(context),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '출근',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.tableHeader(context),
                      ),
                    ),
                  ],
                ),
              ),

              // 데이터 행
              if (provider.recentHistory.isEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveUtils.spacing(context, 24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '아직 기록이 없습니다',
                    style: AppTextStyles.emptyState(context),
                  ),
                )
              else
                ...provider.recentHistory.map(
                  (record) => _buildHistoryRow(context, record),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryRow(BuildContext context, AttendanceRecord record) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 12),
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}',
              style: AppTextStyles.tableCell(context),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.clockIn == null ? '—' : _formatTime(record.clockIn!),
              textAlign: TextAlign.center,
              style: AppTextStyles.tableCell(context, color: AppColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
