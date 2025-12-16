import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';

class AttendanceActionButtons extends StatelessWidget {
  final Function(String msg, {bool error}) onShowBanner;

  const AttendanceActionButtons({super.key, required this.onShowBanner});

  // 지각 여부 체크
  bool _isLateTime() {
    final now = DateTime.now();
    return now.hour > 8 || (now.hour == 8 && now.minute > 30);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        // 모든 플랫폼에서 디버깅 정보 표시
        // Debug code removed
        
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: ResponsiveUtils.spacing(context, 65),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 14),
                    ),
                    onTap: provider.status == AttendanceStatus.beforeWork &&
                            provider.canClockIn &&
                            !provider.isLoading
                        ? () async {
                            // Debug code removed
                            await provider.tryClockIn();
                            if (provider.errorMessage != null) {
                              onShowBanner(provider.errorMessage!, error: true);
                              provider.clearError();
                            } else {
                              onShowBanner('출근 처리되었습니다');
                            }
                          }
                        : null,  // 비활성화 시 완전히 null로 설정
                    child: Container(
                    decoration: BoxDecoration(
                      gradient:
                          provider.status == AttendanceStatus.beforeWork &&
                              !_isLateTime()
                          ? AppColors.primaryGradient
                          : provider.status == AttendanceStatus.beforeWork &&
                              _isLateTime()
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFFF5252), // 진한 빨간색
                                const Color(0xFFE53935), // 더 진한 빨간색
                              ],
                            )
                          : null,
                      color: provider.status != AttendanceStatus.beforeWork
                          ? const Color(0xFFE9ECEF)
                          : null,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 14),
                      ),
                      boxShadow: [
                        if (provider.status == AttendanceStatus.beforeWork)
                          BoxShadow(
                            color: _isLateTime() 
                                ? const Color(0xFFE53935).withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.32),
                            blurRadius: ResponsiveUtils.spacing(context, 7),
                            offset: Offset(
                              0,
                              ResponsiveUtils.spacing(context, 2),
                            ),
                          ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: provider.isClockInLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLateTime() && provider.status == AttendanceStatus.beforeWork) ...[
                                Text(
                                  '지각',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                provider.status == AttendanceStatus.working
                                    ? '정상 출근'
                                    : provider.status == AttendanceStatus.late
                                        ? '지각'
                                        : '출근하기',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontWeight: FontWeight.bold,
                                  fontSize: _isLateTime() && provider.status == AttendanceStatus.beforeWork ? 18 : 21,
                                  color:
                                      provider.status == AttendanceStatus.beforeWork
                                      ? Colors.white
                                      : provider.status == AttendanceStatus.working
                                          ? const Color(0xFF4CAF50) // 정상 출근: 초록색
                                          : provider.status == AttendanceStatus.late
                                              ? const Color(0xFFFF5252) // 지각: 빨간색
                                              : const Color(0xFFB0B0B0),
                                ),
                              ),
                              // Android 디버그 정보 표시
                              if (kDebugMode && !kIsWeb && Platform.isAndroid && provider.status != AttendanceStatus.beforeWork)
                                Column(
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: ${provider.status}',
                                      style: ResponsiveUtils.getTextStyle(context, fontSize: 10, color: Colors.red),
                                    ),
                                    Text(
                                      'ID: ${provider.userId.isNotEmpty ? "OK" : "없음"}',
                                      style: ResponsiveUtils.getTextStyle(context, fontSize: 10, color: Colors.red),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: ResponsiveUtils.spacing(context, 15)),
            Expanded(
              child: SizedBox(
                height: ResponsiveUtils.spacing(context, 65),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 14),
                    ),
                    onTap: provider.canClockOut
                        ? () async {
                            // Debug code removed
                            await provider.tryClockOut();
                            if (provider.errorMessage != null) {
                              onShowBanner(provider.errorMessage!, error: true);
                              provider.clearError();
                            } else {
                              onShowBanner('퇴근 처리되었습니다');
                            }
                          }
                        : null,
                    child: Container(
                    decoration: BoxDecoration(
                      gradient: provider.canClockOut
                          ? AppColors.primaryGradient
                          : null,
                      color: provider.canClockOut
                          ? null
                          : const Color(0xFFE9ECEF),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 14),
                      ),
                      boxShadow: [
                        if (provider.canClockOut)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: ResponsiveUtils.spacing(context, 7),
                            offset: Offset(
                              0,
                              ResponsiveUtils.spacing(context, 2),
                            ),
                          ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: provider.isClockOutLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            '퇴근하기',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.bold,
                              fontSize: 21,
                              color: provider.canClockOut
                                  ? Colors.white
                                  : const Color(0xFFB0B0B0),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
