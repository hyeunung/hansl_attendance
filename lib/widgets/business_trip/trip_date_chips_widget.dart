import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

/// 출장 날짜 칩 위젯
/// 선택된 출장 날짜를 칩 형태로 표시
class TripDateChipsWidget extends StatelessWidget {
  final Set<DateTime> selectedDates;
  final Function(DateTime) onRemove;

  const TripDateChipsWidget({
    Key? key,
    required this.selectedDates,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedDates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '선택된 날짜가 없습니다',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    final sortedDates = selectedDates.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '선택된 날짜 (${selectedDates.length}일)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedDates.map((date) {
              final formattedDate = DateFormat('M/d (E)', 'ko_KR').format(date);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onRemove(date),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 날짜 범위를 문자열로 변환
  static String getDateRangeText(Set<DateTime> dates) {
    if (dates.isEmpty) return '';

    final sortedDates = dates.toList()..sort();
    final first = sortedDates.first;
    final last = sortedDates.last;

    if (first == last) {
      return DateFormat('yyyy년 M월 d일', 'ko_KR').format(first);
    } else {
      return '${DateFormat('M/d', 'ko_KR').format(first)} ~ ${DateFormat('M/d', 'ko_KR').format(last)}';
    }
  }
}
