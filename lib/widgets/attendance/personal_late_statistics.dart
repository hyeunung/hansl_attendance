import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/responsive_utils.dart';

class PersonalLateStatistics extends StatefulWidget {
  const PersonalLateStatistics({super.key});

  @override
  State<PersonalLateStatistics> createState() => _PersonalLateStatisticsState();
}

class _PersonalLateStatisticsState extends State<PersonalLateStatistics> {
  final _supabase = Supabase.instance.client;
  int _monthlyLateCount = 0;
  int _yearlyLateCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLateStatistics();
  }

  Future<void> _loadLateStatistics() async {
    try {
      setState(() => _isLoading = true);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.email;

      if (userEmail == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final thisYear = DateTime(now.year, 1, 1);

      // 이번 달 지각 횟수 조회
      final monthlyData = await _supabase
          .from('attendance_records')
          .select('status')
          .eq('user_email', userEmail)
          .eq('status', '지각')
          .gte('date', thisMonth.toIso8601String().split('T')[0]);

      // 올해 지각 횟수 조회
      final yearlyData = await _supabase
          .from('attendance_records')
          .select('status')
          .eq('user_email', userEmail)
          .eq('status', '지각')
          .gte('date', thisYear.toIso8601String().split('T')[0]);

      if (!mounted) return;
      setState(() {
        _monthlyLateCount = (monthlyData as List).length;
        _yearlyLateCount = (yearlyData as List).length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // 지각이 없으면 표시하지 않음
    if (_monthlyLateCount == 0 && _yearlyLateCount == 0) {
      return const SizedBox.shrink();
    }

    // 플랫 배너 스타일
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 12),
      ),
      decoration: const BoxDecoration(
        color: AppColors.errorLight,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: ResponsiveUtils.iconSize(context, 18),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
          Text(
            '나의 지각',
            style: AppTextStyles.chipLabel(context, color: AppColors.error),
          ),
          const Spacer(),
          _buildStatItem('이번 달', _monthlyLateCount),
          SizedBox(width: ResponsiveUtils.spacing(context, 16)),
          _buildStatItem('올해', _yearlyLateCount),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.statLabel(context),
        ),
        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
        Text(
          '$count회',
          style: AppTextStyles.chipLabel(context, color: AppColors.error).copyWith(
            fontSize: ResponsiveUtils.fontSize(context, 14),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
