import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/attendance_provider.dart';

class AttendanceActionButtons extends StatelessWidget {
  final Function(String msg, {bool error}) onShowBanner;

  const AttendanceActionButtons({super.key, required this.onShowBanner});

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: ResponsiveUtils.spacing(context, 65),
                child: GestureDetector(
                  onTap: provider.status == AttendanceStatus.beforeWork
                      ? () async {
                          await provider.tryClockIn();
                          if (provider.errorMessage != null) {
                            onShowBanner(provider.errorMessage!, error: true);
                            provider.clearError();
                          } else {
                            onShowBanner('출근 처리되었습니다');
                          }
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: provider.status == AttendanceStatus.beforeWork
                          ? AppColors.primaryGradient
                          : null,
                      color: provider.status == AttendanceStatus.beforeWork
                          ? null
                          : const Color(0xFFE9ECEF),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 14),
                      ),
                      boxShadow: [
                        if (provider.status == AttendanceStatus.beforeWork)
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
                    child:
                        provider.isLoading &&
                            provider.status == AttendanceStatus.beforeWork
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : Text(
                            '출근하기',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontWeight: FontWeight.bold,
                              fontSize: 21,
                              color:
                                  provider.status == AttendanceStatus.beforeWork
                                  ? Colors.white
                                  : const Color(0xFFB0B0B0),
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
                child: GestureDetector(
                  onTap: provider.canClockOut
                      ? () async {
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
                    child: provider.isLoading && provider.canClockOut
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
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
          ],
        );
      },
    );
  }
}
