import 'package:flutter/material.dart';
import 'package:hansl/services/feature_flag_service.dart';
import 'package:hansl/theme/app_colors.dart';
import 'package:hansl/utils/logger.dart';

/// Feature Flag 설정 화면 (개발/테스트용)
/// 프로덕션에서는 숨겨져야 합니다.
class FeatureFlagSettingsScreen extends StatefulWidget {
  const FeatureFlagSettingsScreen({Key? key}) : super(key: key);

  @override
  State<FeatureFlagSettingsScreen> createState() => _FeatureFlagSettingsScreenState();
}

class _FeatureFlagSettingsScreenState extends State<FeatureFlagSettingsScreen> {
  final _service = FeatureFlagService();
  Map<String, bool> _flags = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _service.initialize();
      setState(() {
        _flags = _service.getAllFlags();
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Feature Flag 로드 실패', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFlag(String flag, bool value) async {
    await _service.setFlag(flag, value);
    setState(() {
      _flags[flag] = value;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$flag: ${value ? "활성화" : "비활성화"}'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기본값으로 초기화'),
        content: const Text('모든 Feature Flag를 기본값으로 초기화하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('초기화')),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetToDefaults();
      await _loadFlags();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 플래그가 기본값으로 초기화되었습니다'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags (개발용)'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFlags, tooltip: '새로고침'),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: '기본값으로 초기화',
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildFlagList(),
    );
  }

  Widget _buildFlagList() {
    if (_flags.isEmpty) {
      return const Center(
        child: Text('Feature Flag가 없습니다', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    final flagEntries = _flags.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      itemCount: flagEntries.length + 1, // +1 for info card
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildInfoCard();
        }

        final entry = flagEntries[index - 1];
        return _buildFlagTile(entry.key, entry.value);
      },
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Feature Flag 정보',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• 이 화면은 개발/테스트 환경에서만 표시됩니다\n'
              '• 변경사항은 앱을 재시작해야 완전히 적용될 수 있습니다\n'
              '• 프로덕션 배포 전 반드시 적절한 플래그를 설정하세요',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagTile(String flag, bool value) {
    // 플래그에 대한 설명 매핑
    final descriptions = {
      'refactored_leave_screen': '리팩토링된 연차 신청 화면 사용',
      'refactored_business_trip_screen': '리팩토링된 출장 신청 화면 사용',
      'new_validators': '새로운 입력 검증 로직 사용',
      'enhanced_logging': '향상된 로깅 시스템 사용',
      'performance_monitoring': '성능 모니터링 활성화',
      'show_debug_info': '화면에 디버그 정보 표시',
    };

    final description = descriptions[flag] ?? flag;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        title: Text(
          flag,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: (newValue) => _updateFlag(flag, newValue),
        activeColor: AppColors.primary,
        secondary: Icon(
          value ? Icons.check_circle : Icons.radio_button_unchecked,
          color: value ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}

/// Feature Flag 설정 진입점 (설정 화면에서 사용)
class FeatureFlagSettingsTile extends StatelessWidget {
  const FeatureFlagSettingsTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 개발 모드에서만 표시
    if (!_isDevelopmentMode()) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.science, color: Colors.orange),
      title: const Text('Feature Flags (개발용)'),
      subtitle: const Text('실험적 기능 설정'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FeatureFlagSettingsScreen()),
        );
      },
    );
  }

  bool _isDevelopmentMode() {
    // TODO: 실제 개발/프로덕션 환경 구분 로직 구현
    // 예: kDebugMode || Environment.isDevelopment
    return true; // 현재는 항상 표시
  }
}
