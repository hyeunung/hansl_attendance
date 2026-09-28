import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';
import '../shared/flat_section.dart';

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

        final isClockInAction = canTapClockIn;
        final hasAction = canTapClockIn || canTapClockOut;

        return FlatCard(
          child: Column(
            children: [
              FlatCardHeader(
                title: '오늘 근무',
                icon: Icons.today,
                iconColor: AppColors.primary,
                trailing: StatusChip(
                  label: provider.statusText,
                  color: provider.statusColor,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 14),
                  vertical: ResponsiveUtils.spacing(context, 8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTime(
                        context,
                        label: isLateStatus ? '출근 (지각)' : '출근',
                        value: hasClockIn || hasClockOut
                            ? _hm(provider.clockInTime)
                            : '--:--',
                        color: isLateStatus ? AppColors.error : null,
                      ),
                    ),
                    Expanded(
                      child: _buildTime(
                        context,
                        label: '퇴근',
                        value: hasClockOut
                            ? _hm(provider.clockOutTime)
                            : '--:--',
                      ),
                    ),
                    if (hasAction) ...[
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      _buildActionButton(
                        context,
                        label: isClockInAction
                            ? (isLateNow ? '지각 출근' : '출근하기')
                            : '퇴근하기',
                        color: isClockInAction && isLateNow
                            ? AppColors.error
                            : AppColors.primary,
                        isLoading: isClockInAction
                            ? provider.isClockInLoading
                            : provider.isClockOutLoading,
                        onTap: () async {
                          if (isClockInAction) {
                            await provider.tryClockIn();
                          } else {
                            await provider.tryClockOut();
                          }
                          if (provider.errorMessage != null) {
                            onShowBanner(provider.errorMessage!, error: true);
                            provider.clearError();
                          } else {
                            onShowBanner(
                              isClockInAction ? '출근 처리되었습니다' : '퇴근 처리되었습니다',
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _hm(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// 시각 + 라벨 (FlatStatGrid 항목과 같은 규격)
  Widget _buildTime(
    BuildContext context, {
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTextStyles.compactValue(context, color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.compactLabel(context)),
      ],
    );
  }

  /// 출근/퇴근 버튼 (앱 표준 버튼 규격: 높이 36, 모서리 8)
  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 36,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color,
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: AppTextStyles.buttonPrimary(context)),
      ),
    );
  }
}
