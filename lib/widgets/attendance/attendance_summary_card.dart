import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';

class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: AppDecorations.defaultCard,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 섹션 헤더 (회색 배경)
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
                  '오늘의 근무 요약',
                  style: AppTextStyles.sectionHeader(context).copyWith(fontSize: 14),
                ),
              ),

              // 3칸 그리드 (출근시간, 근무시간)
              IntrinsicHeight(
                child: Row(
                  children: [
                    _buildGridCell(
                      context,
                      '출근 시각',
                      provider.clockInStr,
                    ),
                    const VerticalDivider(width: 1, thickness: 0.5, color: AppColors.borderLight),
                    _buildGridCell(
                      context,
                      '근무 시간',
                      provider.todayWorkDuration,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridCell(BuildContext context, String label, String value) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveUtils.spacing(context, 16),
          horizontal: ResponsiveUtils.spacing(context, 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.tableHeader(context),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 4)),
            Text(
              value,
              style: AppTextStyles.compactValue(context),
            ),
          ],
        ),
      ),
    );
  }
}
