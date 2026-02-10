import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/transaction_statement_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';

// ── 업로드 종류 정의 ─────────────────────────────────────
class _UploadType {
  final String key;
  final String label;
  final Color color;

  const _UploadType({
    required this.key,
    required this.label,
    required this.color,
  });
}

const _uploadTypes = [
  _UploadType(
    key: 'default',
    label: '거래명세서',
    color: Color(0xFF1777CB),
  ),
  _UploadType(
    key: 'receipt',
    label: '입고수량',
    color: Color(0xFFEA580C),
  ),
  _UploadType(
    key: 'monthly',
    label: '월말결제',
    color: Color(0xFF059669),
  ),
];

class TransactionStatementScreen extends StatefulWidget {
  const TransactionStatementScreen({super.key});

  @override
  State<TransactionStatementScreen> createState() =>
      _TransactionStatementScreenState();
}

class _TransactionStatementScreenState
    extends State<TransactionStatementScreen> {
  final GlobalKey _uploadFabKey = GlobalKey();
  final _dateFormat = DateFormat('yyyy. MM. dd.');
  final _amountFormat = NumberFormat('#,##0');
  List<TransactionStatementSummary> _statements = [];
  bool _isLoading = true;
  bool _isUploading = false;
  RealtimeChannel? _statementChannel;
  Timer? _realtimeDebounce;
  bool _isRealtimeRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadStatements();
    _setupRealtimeSubscription();
    // 웹앱과 동일: 화면 진입 시 대기열 처리 트리거
    TransactionStatementService.kickQueue();
  }

  Future<void> _loadStatements({bool showLoading = true}) async {
    try {
      if (showLoading) {
        setState(() => _isLoading = true);
      }
      final data = await TransactionStatementService.fetchStatements();
      if (mounted) {
        setState(() {
          _statements = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (showLoading) {
          setState(() => _isLoading = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래명세서 목록을 불러오지 못했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupRealtimeSubscription() {
    final client = Supabase.instance.client;
    _statementChannel = client
        .channel('transaction_statements_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transaction_statements',
          callback: (payload) => _handleRealtimeChange(payload),
        )
        .subscribe();
  }

  static const _terminalStatuses = {
    'extracted',
    'failed',
    'confirmed',
    'rejected',
  };

  void _handleRealtimeChange(PostgresChangePayload payload) {
    // 웹앱과 동일: processing -> terminal 상태 변경 시 다음 큐 처리 트리거
    final oldStatus = payload.oldRecord['status'] as String?;
    final newStatus = payload.newRecord['status'] as String?;
    if (oldStatus == 'processing' &&
        newStatus != null &&
        _terminalStatuses.contains(newStatus)) {
      TransactionStatementService.kickQueue();
    }

    // 모든 변경에 대해 목록 갱신 (디바운스)
    _handleRealtimeRefresh();
  }

  void _handleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_isRealtimeRefreshing) return;
      _isRealtimeRefreshing = true;
      Future.microtask(() async {
        try {
          if (!mounted) return;
          await _loadStatements(showLoading: false);
        } finally {
          _isRealtimeRefreshing = false;
        }
      });
    });
  }

  @override
  void dispose() {
    if (_statementChannel != null) {
      Supabase.instance.client.removeChannel(_statementChannel!);
      _statementChannel = null;
    }
    _realtimeDebounce?.cancel();
    super.dispose();
  }

  // ── 업로드 플로우 ─────────────────────────────────────

  Future<void> _startUploadFlow(ImageSource source) async {
    if (_isUploading) return;
    try {
      final image = await TransactionStatementService.pickImage(source);
      if (image == null) return;
      if (!mounted) return;
      await _showPreviewDialog(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPreviewDialog(XFile image) async {
    bool isUploading = false;
    String selectedType = 'default';
    String? selectedPoScope;
    DateTime? selectedDate;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isMonthly = selectedType == 'monthly';
          final canUpload = isMonthly ||
              (selectedPoScope != null && selectedDate != null);

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 헤더 ──
                    Row(
                      children: [
                        Text(
                          '거래명세서 업로드',
                          style: ResponsiveUtils.getTextStyle(
                            dialogContext,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF9CA3AF),
                          ),
                          tooltip: '닫기',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── 이미지 미리보기 ──
                    _buildImagePreview(File(image.path), isUploading),
                    const SizedBox(height: 16),

                    // ── 업로드 종류 ──
                    _buildFieldLabel(dialogContext, '업로드 종류'),
                    const SizedBox(height: 6),
                    _buildUploadTypeDropdown(
                      context: dialogContext,
                      value: selectedType,
                      enabled: !isUploading,
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                          if (value == 'monthly') {
                            selectedPoScope = null;
                            selectedDate = null;
                          }
                        });
                      },
                    ),

                    // ── 조건부 필드: 거래명세서/입고수량만 표시 ──
                    if (!isMonthly) ...[
                      const SizedBox(height: 14),

                      // 발주/수주 구분
                      _buildFieldLabel(dialogContext, '발주/수주 구분'),
                      const SizedBox(height: 6),
                      _buildPoScopeDropdown(
                        context: dialogContext,
                        value: selectedPoScope,
                        enabled: !isUploading,
                        onChanged: (value) {
                          setDialogState(() => selectedPoScope = value);
                        },
                      ),
                      const SizedBox(height: 14),

                      // 실입고일
                      _buildFieldLabel(dialogContext, '실입고일'),
                      const SizedBox(height: 6),
                      _buildDatePickerField(
                        context: dialogContext,
                        value: selectedDate,
                        enabled: !isUploading,
                        onTap: () async {
                          final picked = await _showStyledDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── 버튼 ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              '다시 선택',
                              style: ResponsiveUtils.getTextStyle(
                                dialogContext,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (isUploading || !canUpload)
                                ? null
                                : () {
                                    // 모달 즉시 닫고 백그라운드 업로드
                                    Navigator.pop(dialogContext);
                                    _executeUploadInBackground(
                                      image: image,
                                      uploadType: selectedType,
                                      poScope: selectedPoScope,
                                      actualReceiptDate: selectedDate,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canUpload
                                  ? AppColors.primary
                                  : const Color(0xFFD1D5DB),
                              disabledBackgroundColor:
                                  const Color(0xFFD1D5DB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              '업로드',
                              style: ResponsiveUtils.getTextStyle(
                                dialogContext,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: canUpload
                                    ? Colors.white
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 모달 내부 위젯 헬퍼 ────────────────────────────────

  Widget _buildFieldLabel(BuildContext ctx, String label) {
    return Row(
      children: [
        Text(
          label,
          style: ResponsiveUtils.getTextStyle(
            ctx,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '*',
          style: ResponsiveUtils.getTextStyle(
            ctx,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTypeDropdown({
    required BuildContext context,
    required String value,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? AppColors.primary : Colors.grey,
          ),
          items: _uploadTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type.key,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: type.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    type.label,
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildPoScopeDropdown({
    required BuildContext context,
    required String? value,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            '선택하세요',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[400],
            ),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? AppColors.primary : Colors.grey,
          ),
          items: [
            DropdownMenuItem(
              value: 'single',
              child: Text(
                '단일 발주',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'multi',
              child: Text(
                '다중 발주',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required DateTime? value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: value != null ? AppColors.primary : Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null
                    ? _dateFormat.format(value)
                    : '날짜를 선택하세요',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: value != null
                      ? const Color(0xFF111827)
                      : Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 앱 디자인에 맞는 커스텀 날짜 선택 다이얼로그
  Future<DateTime?> _showStyledDatePicker({
    required BuildContext context,
    required DateTime initialDate,
  }) async {
    DateTime tempDate = initialDate;
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setPickerState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                '실입고일 선택',
                style: ResponsiveUtils.getTextStyle(
                  dialogCtx,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 선택된 날짜 표시
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(
                        left: 4, right: 4, bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _dateFormat.format(tempDate),
                            style: ResponsiveUtils.getTextStyle(
                              dialogCtx,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 달력
                    Theme(
                      data: Theme.of(dialogCtx).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: const Color(0xFF111827),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        height: 320,
                        child: CalendarDatePicker(
                          initialDate: tempDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          onDateChanged: (picked) {
                            setPickerState(() => tempDate = picked);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '취소',
                          style: ResponsiveUtils.getTextStyle(
                            dialogCtx,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx, tempDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '선택',
                          style: ResponsiveUtils.getTextStyle(
                            dialogCtx,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── 업로드 실행 (백그라운드) ─────────────────────────────

  void _executeUploadInBackground({
    required XFile image,
    required String uploadType,
    String? poScope,
    DateTime? actualReceiptDate,
  }) {
    if (_isUploading) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final uploaderName = (userProvider.employee?['name'] as String?) ??
        userProvider.name ??
        '알 수 없음';
    final typeLabel =
        _uploadTypes.firstWhere((t) => t.key == uploadType).label;

    // 즉시 "업로드 중" optimistic 카드 표시
    final tempId = 'uploading_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _isUploading = true;
      _statements = [
        TransactionStatementSummary(
          id: tempId,
          imageUrl: '',
          fileName: null,
          status: 'uploading',
          statementMode: uploadType,
          uploadedAt: DateTime.now(),
          uploaderName: uploaderName,
          statementDate: null,
          vendorName: null,
          grandTotal: null,
          confirmedByName: null,
        ),
        ..._statements,
      ];
    });

    // 백그라운드에서 실제 업로드 수행
    _performUpload(
      image: image,
      uploadType: uploadType,
      poScope: poScope,
      actualReceiptDate: actualReceiptDate,
      uploaderName: uploaderName,
      typeLabel: typeLabel,
      tempId: tempId,
      messenger: messenger,
    );
  }

  Future<void> _performUpload({
    required XFile image,
    required String uploadType,
    String? poScope,
    DateTime? actualReceiptDate,
    required String uploaderName,
    required String typeLabel,
    required String tempId,
    required ScaffoldMessengerState messenger,
  }) async {
    try {
      final fileSize = await image.length();
      if (fileSize > 10 * 1024 * 1024) {
        _removeOptimisticCard(tempId);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('파일 크기는 10MB 이하여야 합니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      TransactionStatementUploadResult result;
      String optimisticStatus;

      switch (uploadType) {
        case 'receipt':
          result = await TransactionStatementService.uploadReceiptQuantity(
            imageFile: image,
            uploaderName: uploaderName,
            poScope: poScope!,
            actualReceiptDate: actualReceiptDate!,
          );
          optimisticStatus = 'queued';
          break;
        case 'monthly':
          result = await TransactionStatementService.uploadMonthlyStatement(
            imageFile: image,
            uploaderName: uploaderName,
          );
          optimisticStatus = 'processing';
          break;
        default:
          result = await TransactionStatementService.uploadStatement(
            imageFile: image,
            uploaderName: uploaderName,
            poScope: poScope!,
            actualReceiptDate: actualReceiptDate!,
          );
          optimisticStatus = 'queued';
          break;
      }

      if (mounted) {
        // 임시 카드를 실제 결과로 교체
        setState(() {
          _statements = [
            TransactionStatementSummary(
              id: result.statementId,
              imageUrl: result.imageUrl,
              fileName: null,
              status: optimisticStatus,
              statementMode: uploadType,
              uploadedAt: DateTime.now(),
              uploaderName: uploaderName,
              statementDate: null,
              vendorName: null,
              grandTotal: null,
              confirmedByName: null,
            ),
            ..._statements.where((item) => item.id != tempId),
          ];
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('$typeLabel 업로드 완료'),
            backgroundColor: const Color(0xFF34C759),
          ),
        );

        await _loadStatements(showLoading: false);

        // 웹앱 handleUploadSuccess 패턴: default/receipt는 OCR 자동 트리거
        // monthly는 서비스에서 이미 parse-monthly-statement를 호출하므로 제외
        if (uploadType != 'monthly') {
          TransactionStatementService.extractStatementData(
            result.statementId,
            result.imageUrl,
          ).catchError((_) {
            // OCR 트리거 실패는 무시 (Realtime + kickQueue로 재처리)
          });
        }
      }
    } catch (_) {
      _removeOptimisticCard(tempId);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('업로드 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _removeOptimisticCard(String tempId) {
    if (mounted) {
      setState(() {
        _statements =
            _statements.where((item) => item.id != tempId).toList();
      });
    }
  }

  // ── 이미지 미리보기 ───────────────────────────────────

  Widget _buildImagePreview(File imageFile, bool isUploading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Image.file(
                    imageFile,
                    width: constraints.maxWidth,
                    fit: BoxFit.fitWidth,
                  ),
                );
              },
            ),
          ),
        ),
        if (isUploading) ...[
          const SizedBox(height: 10),
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                '업로드 중...',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── FAB 메뉴 ──────────────────────────────────────────

  Future<void> _showUploadOptionsMenu() async {
    if (_isUploading) return;
    final renderBox =
        _uploadFabKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(context, rootNavigator: true)
        .overlay
        ?.context
        .findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    const double menuItemHeight = 36;
    const double menuVerticalPadding = 6;
    const double menuGap = 6;
    const double screenPadding = 8;
    const double menuWidth = 132;
    final double menuHeight = menuItemHeight * 2 + menuVerticalPadding * 2;
    final safePadding = MediaQuery.of(context).padding;
    final fabRect = Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero, ancestor: overlay),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    double menuBottom = (fabRect.top - menuGap).toDouble();
    final double minTop = screenPadding + safePadding.top;
    final double maxBottom =
        overlay.size.height - screenPadding - safePadding.bottom;
    if (menuBottom > maxBottom) {
      menuBottom = maxBottom;
    }
    double menuTop = menuBottom - menuHeight;
    if (menuTop < minTop) {
      menuTop = minTop;
      menuBottom = menuTop + menuHeight;
    }
    final double menuLeft = (fabRect.right - menuWidth)
        .clamp(
          screenPadding + safePadding.left,
          overlay.size.width - menuWidth - screenPadding - safePadding.right,
        )
        .toDouble();

    final selected = await showGeneralDialog<ImageSource>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: menuLeft,
              bottom: overlay.size.height - menuBottom,
              width: menuWidth,
              child: FadeTransition(
                opacity: curved,
                child: SizeTransition(
                  sizeFactor: curved,
                  axisAlignment: 1.0,
                  child: Material(
                    color: Colors.white,
                    elevation: 4,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: menuVerticalPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFabMenuItem(
                            icon: Icons.camera_alt_outlined,
                            label: '촬영',
                            height: menuItemHeight,
                            onTap: () =>
                                Navigator.of(context, rootNavigator: true)
                                    .pop(ImageSource.camera),
                          ),
                          const Divider(
                            height: 1,
                            color: Color(0xFFE5E7EB),
                          ),
                          _buildFabMenuItem(
                            icon: Icons.photo_outlined,
                            label: '보관함',
                            height: menuItemHeight,
                            onTap: () =>
                                Navigator.of(context, rootNavigator: true)
                                    .pop(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder:
          (context, animation, secondaryAnimation, child) => child,
    );
    if (selected != null) {
      await _startUploadFlow(selected);
    }
  }

  Widget _buildFabMenuItem({
    required IconData icon,
    required String label,
    required double height,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 메인 빌드 ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '거래명세서',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: const [],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Text(
              '업로드 목록',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _statements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '업로드된 거래명세서가 없습니다',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadStatements,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _statements.length,
                          itemBuilder: (context, index) {
                            final statement = _statements[index];
                            return _buildStatementCard(statement);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        key: _uploadFabKey,
        onPressed: _showUploadOptionsMenu,
        backgroundColor: AppColors.primary,
        child: _isUploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload, color: Colors.white, size: 20),
      ),
    );
  }

  // ── 리스트 카드 ───────────────────────────────────────

  Widget _buildStatementCard(TransactionStatementSummary statement) {
    final statusStyle = _statusStyle(statement.status);
    final modeStyle = _modeStyle(statement.statementMode);
    final uploadedAt = _formatDate(statement.uploadedAt);
    final statementDate = _formatDate(statement.statementDate);
    final vendorName = statement.vendorName ?? '-';
    final grandTotal = _formatAmount(statement.grandTotal);
    final uploaderName = statement.uploaderName ?? '-';
    final confirmedByName = statement.confirmedByName ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 뱃지 + 종류 뱃지
            Row(
              children: [
                // 종류 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: modeStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    modeStyle.label,
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: modeStyle.foregroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 상태 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusStyle.icon,
                        size: 14,
                        color: statusStyle.foregroundColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusStyle.label,
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusStyle.foregroundColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('업로드일', uploadedAt),
            _buildInfoRow('명세서일', statementDate),
            _buildInfoRow('거래처명', vendorName),
            _buildInfoRow('합계금액', grandTotal),
            _buildInfoRow('등록자', uploaderName),
            _buildInfoRow('확정자', confirmedByName),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return _dateFormat.format(dateTime);
  }

  String _formatAmount(num? amount) {
    if (amount == null) return '-';
    return '${_amountFormat.format(amount)}원';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 13,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 상태/종류 스타일 ──────────────────────────────────

  _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'uploading':
        return _StatusStyle(
          label: '업로드 중',
          icon: Icons.cloud_upload_outlined,
          backgroundColor: const Color(0xFFFFF7ED),
          foregroundColor: const Color(0xFFEA580C),
        );
      case 'pending':
        return _StatusStyle(
          label: '대기중',
          icon: Icons.schedule,
          backgroundColor: const Color(0xFFF2F4F7),
          foregroundColor: const Color(0xFF667085),
        );
      case 'queued':
        return _StatusStyle(
          label: '대기열',
          icon: Icons.schedule,
          backgroundColor: const Color(0xFFEEF0F4),
          foregroundColor: const Color(0xFF475569),
        );
      case 'processing':
        return _StatusStyle(
          label: '처리중',
          icon: Icons.autorenew,
          backgroundColor: const Color(0xFFE8F1FF),
          foregroundColor: const Color(0xFF2F80ED),
        );
      case 'extracted':
        return _StatusStyle(
          label: '확인필요',
          icon: Icons.info_outline,
          backgroundColor: const Color(0xFFFFF4E5),
          foregroundColor: const Color(0xFFB54708),
        );
      case 'confirmed':
        return _StatusStyle(
          label: '확정됨',
          icon: Icons.check_circle_outline,
          backgroundColor: const Color(0xFFE8F5E9),
          foregroundColor: const Color(0xFF2E7D32),
        );
      case 'rejected':
        return _StatusStyle(
          label: '거부됨',
          icon: Icons.cancel_outlined,
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: const Color(0xFFD32F2F),
        );
      case 'failed':
        return _StatusStyle(
          label: '실패',
          icon: Icons.error_outline,
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: const Color(0xFFD32F2F),
        );
      default:
        return _StatusStyle(
          label: status,
          icon: Icons.help_outline,
          backgroundColor: const Color(0xFFF2F4F7),
          foregroundColor: const Color(0xFF667085),
        );
    }
  }

  _ModeStyle _modeStyle(String mode) {
    switch (mode) {
      case 'receipt':
        return _ModeStyle(
          label: '입고수량',
          backgroundColor: const Color(0xFFFFF7ED),
          foregroundColor: const Color(0xFFEA580C),
        );
      case 'monthly':
        return _ModeStyle(
          label: '월말결제',
          backgroundColor: const Color(0xFFECFDF5),
          foregroundColor: const Color(0xFF059669),
        );
      default:
        return _ModeStyle(
          label: '일반',
          backgroundColor: const Color(0xFFEFF6FF),
          foregroundColor: const Color(0xFF1777CB),
        );
    }
  }
}

// ── 스타일 클래스 ────────────────────────────────────────

class _StatusStyle {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  _StatusStyle({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}

class _ModeStyle {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  _ModeStyle({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}
