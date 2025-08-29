import 'package:flutter/material.dart';
import 'package:hansl/services/feature_flag_service.dart';
import 'package:hansl/services/performance_monitor.dart';
import 'attendance_screen.dart';
import 'attendance_screen_optimized.dart';

/// 출석 화면 라우터
/// Feature Flag에 따라 기존 화면 또는 리팩토링된 화면을 보여줌
class AttendanceScreenRouter extends StatelessWidget {
  const AttendanceScreenRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();

    Widget screen;

    if (FeatureFlags.useRefactoredAttendanceScreen) {
      // 리팩토링된 화면 사용
      screen = const AttendanceScreenOptimized();

      PerformanceMonitor.trackScreenLoad(
        'AttendanceScreenOptimized',
        stopwatch.elapsed,
      );
    } else {
      // 기존 화면 사용
      screen = const AttendanceScreen();

      PerformanceMonitor.trackScreenLoad('AttendanceScreen', stopwatch.elapsed);
    }

    return screen;
  }
}
