import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../providers/leave_provider.dart';
import '../shared/flat_section.dart';

/// 오늘의 근태현황 - 회사에 없는 사람 (연차, 출장, 공가)
class TodayAbsenceWidget extends StatefulWidget {
  const TodayAbsenceWidget({super.key});

  @override
  State<TodayAbsenceWidget> createState() => _TodayAbsenceWidgetState();
}

class _TodayAbsenceWidgetState extends State<TodayAbsenceWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<LeaveProvider>(context, listen: false);
        provider.fetchTodayLeaves(DateTime.now());
      }
    });
  }

  String _typeLabel(String? type) {
    if (type == null) return '기타';
    final t = type.toLowerCase().replaceAll('_', '');
    switch (t) {
      case 'annual':
        return '연차';
      case 'halfam':
        return '오전반차';
      case 'halfpm':
        return '오후반차';
      case 'biztrip':
      case 'businesstrip':
        return '출장';
      case 'official':
        return '공가';
      default:
        return '기타';
    }
  }

  Color _typeColor(String? type) {
    if (type == null) return AppColors.textTertiary;
    final t = type.toLowerCase().replaceAll('_', '');
    switch (t) {
      case 'annual':
      case 'halfam':
      case 'halfpm':
        return AppColors.success;
      case 'biztrip':
      case 'businesstrip':
        return AppColors.biztrip;
      case 'official':
        return AppColors.official;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveProvider>(
      builder: (context, provider, _) {
        final leaves = provider.todayLeaves;

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              FlatSectionHeader(
                title: '오늘의 근태현황',
                trailing: '${leaves.length}명',
              ),

              FlatTableColumnHeader(
                columns: [
                  const FlatColumn(label: '이름', flex: 2),
                  const FlatColumn(label: '구분', flex: 2, align: TextAlign.center),
                  const FlatColumn(label: '사유/출장지', flex: 3),
                ],
              ),

              if (leaves.isEmpty)
                const FlatEmptyState(message: '오늘 부재 직원이 없습니다.')
              else
                ...leaves.map((l) => _buildRow(context, l)),
            ],
          ),
        );
      },
    );
  }

  /// 출장이면 출장지, 연차/공가면 사유 반환
  String _detailText(Map<String, dynamic> l) {
    final isCompanion = l['is_companion'] == true;
    final type = (l['type'] as String? ?? '').toLowerCase().replaceAll('_', '');
    if (type == 'biztrip' || type == 'businesstrip') {
      if (isCompanion) return '';
      return (l['place'] as String?) ?? '';
    }
    return (l['reason'] as String?) ?? '';
  }

  Widget _buildRow(BuildContext context, Map<String, dynamic> l) {
    final name = l['name'] ?? l['user_email'] ?? '-';
    final type = l['type'] as String?;
    final label = _typeLabel(type);
    final color = _typeColor(type);
    final detail = _detailText(l);
    final isCompanion = l['is_companion'] == true;

    return FlatTableRow(
      cells: [
        Row(
          children: [
            if (isCompanion)
              Text(
                ' ㄴ',
                style: AppTextStyles.tableCell(context).copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            Flexible(
              child: Text(
                name,
                style: AppTextStyles.tableCell(context).copyWith(
                  color: isCompanion ? AppColors.textSecondary : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: StatusChip(label: label, color: color, fontSize: 12),
        ),
        Text(
          detail,
          style: AppTextStyles.tableCell(context).copyWith(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      flexValues: const [2, 2, 3],
    );
  }
}
