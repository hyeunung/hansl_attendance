import 'package:flutter/material.dart';
import 'package:hansl/services/feature_flag_service.dart';
import 'package:hansl/services/performance_monitor.dart';
import 'package:hansl/utils/logger.dart';
import 'annual_leave_request_screen.dart';
import 'annual_leave_request_screen_optimized.dart';
import 'business_trip_request_screen.dart';
import 'business_trip_request_screen_optimized.dart';

/// 연차 신청 화면 라우터
/// Feature Flag에 따라 적절한 화면을 반환합니다.
class LeaveScreenRouter extends StatefulWidget {
  const LeaveScreenRouter({Key? key}) : super(key: key);

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

    AppLogger.info('연차 신청 화면 라우팅: $_screenVersion');
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
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Version: $_screenVersion',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      );
    }

    return _buildScreen();
  }

  Widget _buildScreen() {
    if (FeatureFlags.useRefactoredLeaveScreen) {
      // 새로운 최적화된 화면 사용
      return const AnnualLeaveRequestScreenOptimized();
    } else {
      // 기존 화면 사용
      return const AnnualLeaveRequestScreen();
    }
  }
}

/// 출장 신청 화면 라우터
class BusinessTripScreenRouter extends StatefulWidget {
  const BusinessTripScreenRouter({Key? key}) : super(key: key);

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

    AppLogger.info('출장 신청 화면 라우팅: $_screenVersion');
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
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Version: $_screenVersion',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      );
    }

    return _buildScreen();
  }

  Widget _buildScreen() {
    if (FeatureFlags.useRefactoredBusinessTripScreen) {
      // 새로운 리팩토링된 화면 사용
      return const BusinessTripRequestScreenOptimized();
    } else {
      // 기존 화면 사용
      return const BusinessTripRequestScreen();
    }
  }
}
