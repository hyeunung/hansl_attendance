import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/validators/leave_validators.dart';

/// 출장 정보 입력 위젯
/// 출장지와 업무 내용을 입력받는 위젯
class TripInfoInputWidget extends StatelessWidget {
  final TextEditingController placeController;
  final TextEditingController purposeController;
  final FocusNode? placeFocusNode;
  final FocusNode? purposeFocusNode;
  final Set<DateTime> selectedDates;
  final VoidCallback? onSelectDates;
  final Function(DateTime)? onRemoveDate;
  final Function(String)? onPlaceChanged;
  final Function(String)? onPurposeChanged;

  const TripInfoInputWidget({
    Key? key,
    required this.placeController,
    required this.purposeController,
    required this.selectedDates,
    this.placeFocusNode,
    this.purposeFocusNode,
    this.onSelectDates,
    this.onRemoveDate,
    this.onPlaceChanged,
    this.onPurposeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPlaceSection(),
        const SizedBox(height: 16),
        _buildPurposeSection(),
      ],
    );
  }

  Widget _buildDateSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppShadows.card],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('날짜', isRequired: true),
          const SizedBox(height: 10),
          _buildDateSelector(),
          if (selectedDates.isNotEmpty) _buildDateChips(),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: onSelectDates,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedDates.isNotEmpty
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: selectedDates.isNotEmpty ? AppColors.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _getDateDisplayText(),
                style: TextStyle(
                  fontSize: 15,
                  color: selectedDates.isNotEmpty
                      ? AppColors.primary
                      : Colors.grey,
                  fontWeight: selectedDates.isNotEmpty
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selectedDates.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedDates.length}일',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDateDisplayText() {
    if (selectedDates.isEmpty) {
      return '출장 날짜를 선택하세요';
    }

    final sortedDates = selectedDates.toList()..sort();

    // 연속된 날짜인지 확인
    bool isConsecutive = true;
    for (int i = 1; i < sortedDates.length; i++) {
      if (sortedDates[i].difference(sortedDates[i - 1]).inDays != 1) {
        isConsecutive = false;
        break;
      }
    }

    if (isConsecutive && sortedDates.length > 1) {
      // 연속된 날짜면 "시작일 ~ 종료일" 형식으로 표시
      final start = DateFormat('yyyy.MM.dd').format(sortedDates.first);
      final end = DateFormat('yyyy.MM.dd').format(sortedDates.last);
      return '$start ~ $end';
    } else if (sortedDates.length == 1) {
      // 하루만 선택된 경우
      return DateFormat('yyyy.MM.dd').format(sortedDates.first);
    } else {
      // 불연속 날짜들
      return sortedDates
              .take(3)
              .map((d) => DateFormat('MM.dd').format(d))
              .join(', ') +
          (sortedDates.length > 3 ? ' 외 ${sortedDates.length - 3}일' : '');
    }
  }

  Widget _buildDateChips() {
    final sortedDates = selectedDates.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sortedDates.map((date) {
          return Chip(
            label: Text(
              DateFormat('yyyy.MM.dd (E)', 'ko').format(date),
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            deleteIcon: const Icon(Icons.close, size: 16),
            deleteIconColor: AppColors.primary,
            onDeleted: onRemoveDate != null ? () => onRemoveDate!(date) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlaceSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppShadows.card],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('출장지', isRequired: true),
          const SizedBox(height: 10),
          _buildPlaceInput(),
        ],
      ),
    );
  }

  Widget _buildPlaceInput() {
    final placeError = LeaveValidators.validatePlace(
      placeController.text.isEmpty ? null : placeController.text,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: placeController.text.isNotEmpty
              ? (placeError != null
                    ? Colors.red.withValues(alpha: 0.3)
                    : AppColors.primary.withValues(alpha: 0.3))
              : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: placeController.text.isNotEmpty
                    ? AppColors.primary
                    : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: placeController,
                  focusNode: placeFocusNode,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF222222),
                  ),
                  decoration: const InputDecoration(
                    hintText: '출장지를 입력하세요',
                    hintStyle: TextStyle(fontSize: 15, color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: onPlaceChanged,
                  maxLength: 100,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) {
                        if (isFocused && currentLength > 0) {
                          return Text(
                            '$currentLength / $maxLength',
                            style: TextStyle(
                              fontSize: 12,
                              color: currentLength == maxLength
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          );
                        }
                        return null;
                      },
                ),
              ),
            ],
          ),
          if (placeError != null && placeController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 28),
              child: Text(
                placeError,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPurposeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppShadows.card],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('업무', isRequired: true),
          const SizedBox(height: 10),
          _buildPurposeInput(),
        ],
      ),
    );
  }

  Widget _buildPurposeInput() {
    final purposeError = LeaveValidators.validatePurpose(
      purposeController.text.isEmpty ? null : purposeController.text,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: purposeController.text.isNotEmpty
              ? (purposeError != null
                    ? Colors.red.withValues(alpha: 0.3)
                    : AppColors.primary.withValues(alpha: 0.3))
              : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: purposeController,
            focusNode: purposeFocusNode,
            maxLines: 4,
            maxLength: 1000,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF222222),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '출장 업무 내용을 상세히 입력하세요\n(최소 10자 이상)',
              hintStyle: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                height: 1.5,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onPurposeChanged,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (purposeError != null &&
                          purposeController.text.isNotEmpty)
                        Expanded(
                          child: Text(
                            purposeError,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      Text(
                        '$currentLength / $maxLength',
                        style: TextStyle(
                          fontSize: 12,
                          color: currentLength == maxLength
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        if (isRequired)
          const Text('  *', style: TextStyle(color: Colors.red, fontSize: 17)),
      ],
    );
  }
}
