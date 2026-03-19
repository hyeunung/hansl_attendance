import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';

class AttendanceActionButtons extends StatelessWidget {
  final Function(String msg, {bool error}) onShowBanner;

  const AttendanceActionButtons({super.key, required this.onShowBanner});

  bool _isLateTime() {
    final now = DateTime.now();
    return now.hour > 8 || (now.hour == 8 && now.minute > 30);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        final hasClockIn = provider.status == AttendanceStatus.working ||
            provider.status == AttendanceStatus.late;
        final hasClockOut = provider.status == AttendanceStatus.offWork;
        final isBeforeWork = provider.status == AttendanceStatus.beforeWork;
        final canTapClockIn = isBeforeWork && provider.canClockIn && !provider.isLoading;
        final canTapClockOut = provider.canClockOut;
        final isLateNow = isBeforeWork && _isLateTime();
        final isLateStatus = provider.status == AttendanceStatus.late;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 출근 영역
                Expanded(
                  child: canTapClockIn
                      ? _buildButtonMode(
                          context,
                          label: isLateNow ? '지각 출근' : '출근하기',
                          isLoading: provider.isClockInLoading,
                          color: isLateNow ? AppColors.error : AppColors.primary,
                          isLeft: true,
                          onTap: () async {
                            await provider.tryClockIn();
                            if (provider.errorMessage != null) {
                              onShowBanner(provider.errorMessage!, error: true);
                              provider.clearError();
                            } else {
                              onShowBanner('출근 처리되었습니다');
                            }
                          },
                        )
                      : _buildStatusMode(
                          context,
                          title: isLateStatus ? '출근 (지각)' : '출근',
                          time: hasClockIn ? provider.clockInStr : '--:--',
                          statusText: isLateStatus ? '지각' : (hasClockIn ? '기록됨' : '미기록'),
                          isActive: hasClockIn,
                          accentColor: hasClockIn
                              ? (isLateStatus ? AppColors.late_ : AppColors.success)
                              : null,
                        ),
                ),

                Container(width: 0.5, color: AppColors.border),

                // 퇴근 영역
                Expanded(
                  child: canTapClockOut
                      ? _buildButtonMode(
                          context,
                          label: '퇴근하기',
                          isLoading: provider.isClockOutLoading,
                          color: AppColors.primary,
                          isLeft: false,
                          onTap: () async {
                            await provider.tryClockOut();
                            if (provider.errorMessage != null) {
                              onShowBanner(provider.errorMessage!, error: true);
                              provider.clearError();
                            } else {
                              onShowBanner('퇴근 처리되었습니다');
                            }
                          },
                        )
                      : _buildStatusMode(
                          context,
                          title: '퇴근',
                          time: hasClockOut ? '완료' : '--:--',
                          statusText: hasClockOut ? '기록됨' : '미기록',
                          isActive: hasClockOut,
                          accentColor: hasClockOut ? AppColors.primary : null,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 탭 가능 상태 — 버튼 느낌
  Widget _buildButtonMode(
    BuildContext context, {
    required String label,
    required bool isLoading,
    required Color color,
    required bool isLeft,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isLeft ? 9 : 0),
        bottomLeft: Radius.circular(isLeft ? 9 : 0),
        topRight: Radius.circular(isLeft ? 0 : 9),
        bottomRight: Radius.circular(isLeft ? 0 : 9),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? 9 : 0),
          bottomLeft: Radius.circular(isLeft ? 9 : 0),
          topRight: Radius.circular(isLeft ? 0 : 9),
          bottomRight: Radius.circular(isLeft ? 0 : 9),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.spacing(context, 20),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.buttonPrimary(context),
                ),
        ),
      ),
    );
  }

  /// 기록 완료 — 상태 표시
  Widget _buildStatusMode(
    BuildContext context, {
    required String title,
    required String time,
    required String statusText,
    required bool isActive,
    Color? accentColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTextStyles.sectionSubtitle(context),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                Text(
                  '$time $statusText',
                  style: AppTextStyles.statLabel(context),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? (accentColor ?? AppColors.textPrimary)
                  : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? (accentColor ?? AppColors.textPrimary)
                    : AppColors.gray300,
                width: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
