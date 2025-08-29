import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/user_provider.dart';

class AttendanceStatusCard extends StatelessWidget {
  const AttendanceStatusCard({super.key});

  LinearGradient _getStatusGradient(String statusText) {
    switch (statusText) {
      case '지각':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
        );
      case '정상 출근':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1777CB), Color(0xFF0D4F8C)],
        );
      case '퇴근':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9E9E9E), Color(0xFF757575)],
        );
    }
  }

  Color _getStatusShadowColor(String statusText) {
    switch (statusText) {
      case '지각':
        return const Color(0xFFEE5A24).withValues(alpha: 0.3);
      case '정상 출근':
        return const Color(0xFF0D4F8C).withValues(alpha: 0.3);
      case '퇴근':
        return const Color(0xFF45A049).withValues(alpha: 0.3);
      default:
        return const Color(0xFF757575).withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.spacing(context, 30),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.spacing(context, 20),
            ),
            boxShadow: [AppShadows.card],
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 사용자 이름 추가
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  final name = userProvider.name ?? '-';
                  return Text(
                    '$name님',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1777CB),
                    ),
                  );
                },
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 24),
                  vertical: ResponsiveUtils.spacing(context, 12),
                ),
                decoration: BoxDecoration(
                  gradient: _getStatusGradient(provider.statusText),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusShadowColor(provider.statusText),
                      blurRadius: ResponsiveUtils.spacing(context, 15),
                      offset: Offset(0, ResponsiveUtils.spacing(context, 4)),
                    ),
                  ],
                ),
                child: Text(
                  provider.statusText,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 15)),
              Text(
                provider.clockInTime == null
                    ? '-'
                    : '${provider.clockInStr} 부터',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF6C757D),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
