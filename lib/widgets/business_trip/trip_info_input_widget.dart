import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/validators/leave_validators.dart';
import '../../utils/responsive_utils.dart';

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
    super.key,
    required this.placeController,
    required this.purposeController,
    required this.selectedDates,
    this.placeFocusNode,
    this.purposeFocusNode,
    this.onSelectDates,
    this.onRemoveDate,
    this.onPlaceChanged,
    this.onPurposeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPlaceSection(context),
        const SizedBox(height: 16),
        _buildPurposeSection(context),
      ],
    );
  }

  // 현재 사용되지 않는 메서드 - 필요시 활성화
  //       color: Colors.white,
  //       boxShadow: AppShadows.cardShadow,
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [



  Widget _buildPlaceSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, '출장지', isRequired: true),
          const SizedBox(height: 10),
          _buildPlaceInput(context),
        ],
      ),
    );
  }

  Widget _buildPlaceInput(BuildContext context) {
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
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 16,
                    color: Color(0xFF222222),
                  ),
                  decoration: const InputDecoration(
                    hintText: '출장지를 입력하세요',
                    hintStyle: const TextStyle(fontSize: 15, color: Colors.grey),
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
                            style: ResponsiveUtils.getTextStyle(
                              context,
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
                style: ResponsiveUtils.getTextStyle(context, color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPurposeSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, '업무', isRequired: true),
          const SizedBox(height: 10),
          _buildPurposeInput(context),
        ],
      ),
    );
  }

  Widget _buildPurposeInput(BuildContext context) {
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
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 16,
              color: Color(0xFF222222),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '출장 업무 내용을 상세히 입력하세요\n(최소 10자 이상)',
              hintStyle: ResponsiveUtils.getTextStyle(
                context,
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
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      Text(
                        '$currentLength / $maxLength',
                        style: ResponsiveUtils.getTextStyle(
                          context,
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

  Widget _buildSectionHeader(BuildContext context, String title, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          title,
          style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        if (isRequired)
          Text('  *', style: ResponsiveUtils.getTextStyle(context, color: Colors.red, fontSize: 17)),
      ],
    );
  }
}
