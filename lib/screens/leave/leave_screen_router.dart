import 'package:flutter/material.dart';
import 'package:hansl/services/feature_flag_service.dart';
import 'package:hansl/services/performance_monitor.dart';
import '../../utils/responsive_utils.dart';
import 'annual_leave_request_screen_optimized.dart';
import 'business_trip_request_screen_optimized.dart';

/// 연차 신청 화면 라우터
/// Feature Flag에 따라 적절한 화면을 반환합니다.
class LeaveScreenRouter extends StatefulWidget {
  const LeaveScreenRouter({super.key});

  @override
  State<LeaveScreenRouter> createState() => _LeaveScreenRouterState();
}

class _LeaveScreenRouterState extends State<LeaveScreenRouter> {
  final _stopwatch = Stopwatch();
  late final String _screenVersion;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();

    // 어떤 버전을 사용할지 결정
    _screenVersion = FeatureFlags.useRefactoredLeaveScreen
        ? 'optimized'
        : 'original';

    // Debug code removed
  }

  @override
  void dispose() {
    _stopwatch.stop();

    // 성능 메트릭 기록
    if (FeatureFlags.performanceMonitoring) {
      PerformanceMonitor.trackScreenLoad(
        'leave_request_$_screenVersion',
        _stopwatch.elapsed,
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Feature Flag 디버그 정보 표시
    if (FeatureFlags.showDebugInfo) {
      return Stack(
        children: [
          _buildScreen(),
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Version: $_screenVersion',
                style: ResponsiveUtils.getTextStyle(context, color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      );
    }

    return _buildScreen();
  }

  Widget _buildScreen() {
    return const AnnualLeaveRequestScreenOptimized();
  }
}

/// 출장 신청 화면 라우터
class BusinessTripScreenRouter extends StatefulWidget {
  const BusinessTripScreenRouter({super.key});

  @override
  State<BusinessTripScreenRouter> createState() =>
      _BusinessTripScreenRouterState();
}

class _BusinessTripScreenRouterState extends State<BusinessTripScreenRouter> {
  final _stopwatch = Stopwatch();
  late final String _screenVersion;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();

    // 어떤 버전을 사용할지 결정
    _screenVersion = FeatureFlags.useRefactoredBusinessTripScreen
        ? 'refactored'
        : 'original';

    // Debug code removed
  }

  @override
  void dispose() {
    _stopwatch.stop();

    // 성능 메트릭 기록
    if (FeatureFlags.performanceMonitoring) {
      PerformanceMonitor.trackScreenLoad(
        'business_trip_$_screenVersion',
        _stopwatch.elapsed,
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Feature Flag 디버그 정보 표시
    if (FeatureFlags.showDebugInfo) {
      return Stack(
        children: [
          _buildScreen(),
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Version: $_screenVersion',
                style: ResponsiveUtils.getTextStyle(context, color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      );
    }

    return _buildScreen();
  }

  Widget _buildScreen() {
    return const BusinessTripRequestScreenOptimized();
  }
}
