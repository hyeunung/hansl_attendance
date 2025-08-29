import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';

class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({super.key});

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 17,
                color: const Color(0xFF6C757D),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF343A40),
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
          Container(height: 1, color: const Color(0xFFF1F3F4)),
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 25)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.spacing(context, 20),
            ),
            boxShadow: [AppShadows.card],
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.spacing(context, 2),
                    ),
                    child: Text(
                      '💼',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                  Text(
                    '오늘의 근무 요약',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: const Color(0xFF343A40),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),
              _buildSummaryItem(context, '출근 시간', provider.clockInStr),
              _buildSummaryItem(
                context,
                '근무 시간',
                provider.todayWorkDuration,
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }
}
