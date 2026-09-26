import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin_attendance_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/common/notification_banner_widget.dart';

/// 근태 기록 수정 바텀시트
///
/// 관리자(hr/superadmin)가 직원의 출근/퇴근 시간, 상태, 비고를 수정.
/// 시간은 HH:MM 형식으로 직접 입력 가능 (TimePicker 다이얼 미사용).
class AdminAttendanceEditSheet extends StatefulWidget {
  final Map<String, dynamic> record;
  final VoidCallback onSaved;

  const AdminAttendanceEditSheet({
    super.key,
    required this.record,
    required this.onSaved,
  });

  @override
  State<AdminAttendanceEditSheet> createState() =>
      _AdminAttendanceEditSheetState();
}

class _AdminAttendanceEditSheetState extends State<AdminAttendanceEditSheet> {
  final AdminAttendanceService _service = AdminAttendanceService();
  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _clockInCtrl = TextEditingController();
  final TextEditingController _clockOutCtrl = TextEditingController();

  String? _status;
  bool _saving = false;

  static const List<String> _statusOptions = [
    '정상 출근',
    '지각',
    '퇴근',
    '오전반차',
    '오후반차',
  ];

  @override
  void initState() {
    super.initState();
    _clockInCtrl.text = _normalize(widget.record['clock_in'] as String?);
    _clockOutCtrl.text = _normalize(widget.record['clock_out'] as String?);
    final status = widget.record['status'] as String?;
    if (status != null && _statusOptions.contains(status)) {
      _status = status;
    }
    _remarksCtrl.text = (widget.record['remarks'] ?? '') as String;
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    _clockInCtrl.dispose();
    _clockOutCtrl.dispose();
    super.dispose();
  }

  /// DB에서 가져온 "HH:MM:SS" or "HH:MM" → "HH:MM"으로 정규화
  String _normalize(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  /// 입력 값이 유효한 HH:MM 형식인지 검증
  /// 빈 문자열도 유효 (= 시간 기록 없음)
  bool _isValidTime(String value) {
    if (value.isEmpty) return true;
    final regex = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');
    return regex.hasMatch(value);
  }

  Future<void> _save() async {
    final empId = widget.record['employee_id'] as String?;
    final empName = widget.record['employee_name'] as String?;
    final email = widget.record['email'] as String?;
    final date = widget.record['date'] as String?;

    if (empId == null || empName == null || email == null || date == null) {
      AppBanner.show(context, '직원 정보가 누락되었습니다', type: BannerType.error);
      return;
    }

    final clockIn = _clockInCtrl.text.trim();
    final clockOut = _clockOutCtrl.text.trim();

    // 유효성 검증
    if (!_isValidTime(clockIn)) {
      AppBanner.show(context, '출근 시간 형식이 올바르지 않습니다 (HH:MM)',
          type: BannerType.error);
      return;
    }
    if (!_isValidTime(clockOut)) {
      AppBanner.show(context, '퇴근 시간 형식이 올바르지 않습니다 (HH:MM)',
          type: BannerType.error);
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.updateAttendanceRecord(
        attendanceId: widget.record['attendance_id'] as int?,
        employeeId: empId,
        employeeName: empName,
        userEmail: email,
        date: date,
        clockIn: clockIn,
        clockOut: clockOut,
        status: _status ?? '',
        remarks: _remarksCtrl.text.trim(),
      );
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppBanner.show(context, '저장 실패: $e', type: BannerType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final name = widget.record['employee_name'] ?? '-';
    final date = widget.record['date'] ?? '-';

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Text(name, style: AppTextStyles.appBarTitle(context)),
              const SizedBox(height: 1),
              Text(
                '$date · 근태 수정',
                style: AppTextStyles.listSubtitle(context),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 12),

              // 출근 시간 (직접 입력)
              _label('출근 시간'),
              _timeInputField(_clockInCtrl),
              const SizedBox(height: 12),

              // 퇴근 시간 (직접 입력)
              _label('퇴근 시간'),
              _timeInputField(_clockOutCtrl),
              const SizedBox(height: 12),

              // 상태
              _label('상태'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _statusOptions.map((s) {
                  final selected = _status == s;
                  return ChoiceChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _status = selected ? null : s),
                    selectedColor: AppColors.primary,
                    labelStyle: AppTextStyles.compactLabel(context).copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color:
                          selected ? AppColors.primary : AppColors.border,
                    ),
                    backgroundColor: Colors.white,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 비고
              _label('비고'),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _remarksCtrl,
                  maxLines: 2,
                  style: AppTextStyles.cardBody(context),
                  decoration: const InputDecoration(
                    hintText: '예: GPS 오류로 수동 보정',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: AppTextStyles.listSubtitle(context)),
    );
  }

  /// HH:MM 직접 입력 필드 (TimePicker 다이얼 미사용)
  /// 숫자 키보드 + 자동 콜론 삽입 + 5자 제한
  Widget _timeInputField(TextEditingController controller) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.access_time,
                size: 16, color: AppColors.textTertiary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(5),
                _TimeInputFormatter(),
              ],
              decoration: const InputDecoration(
                hintText: 'HH:MM (예: 09:15)',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTextStyles.tableCell(context),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear,
                  size: 16, color: AppColors.textTertiary),
              onPressed: () => setState(() => controller.clear()),
            ),
        ],
      ),
    );
  }
}

/// 숫자 입력 시 자동으로 "HH:MM" 형식으로 콜론 삽입
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 숫자만 추출
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // 빈 문자열이면 그대로
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // 최대 4자리 (HHMM)
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;

    String formatted;
    if (limited.length <= 2) {
      // 1~2자리: HH
      formatted = limited;
    } else {
      // 3~4자리: HH:MM
      formatted = '${limited.substring(0, 2)}:${limited.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
