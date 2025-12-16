import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
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

    // 한 줄로 간결한 디자인
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 20)),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 20),
        vertical: ResponsiveUtils.spacing(context, 14),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE57373), // 파스텔 레드
            const Color(0xFFEF5350), // 약간 더 진한 파스텔 레드
          ],
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 16),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE57373).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: ResponsiveUtils.iconSize(context, 20),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 12)),
          Text(
            '나의 지각 현황',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 20)),
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 20)),
          _buildStatItem('이번 달', _monthlyLateCount),
          SizedBox(width: ResponsiveUtils.spacing(context, 24)),
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
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.spacing(context, 10),
            vertical: ResponsiveUtils.spacing(context, 4),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count회',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}