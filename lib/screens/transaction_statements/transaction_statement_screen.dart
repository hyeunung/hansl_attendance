import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/transaction_statement_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../widgets/shared/flat_section.dart';

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
    color: AppColors.primary,
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
        AppBanner.show(context, '거래명세서 목록을 불러오지 못했습니다.', type: BannerType.error);
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
        AppBanner.show(context, '이미지 선택 실패: $e', type: BannerType.error);
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
                          style: AppTextStyles.sectionSubtitle(dialogContext),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textDisabled,
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
                                color: AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              '다시 선택',
                              style: AppTextStyles.inputLabel(dialogContext).copyWith(
                                fontWeight: FontWeight.w600,
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
                                  : AppColors.gray300,
                              disabledBackgroundColor:
                                  AppColors.gray300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              '업로드',
                              style: AppTextStyles.inputLabel(dialogContext).copyWith(
                                fontWeight: FontWeight.w600,
                                color: canUpload
                                    ? Colors.white
                                    : AppColors.textDisabled,
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
          style: AppTextStyles.sectionHeader(context).copyWith(
            color: AppColors.gray700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '*',
          style: AppTextStyles.sectionHeader(context).copyWith(
            color: AppColors.error,
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
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? AppColors.primary : AppColors.textDisabled,
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
                    style: AppTextStyles.inputLabel(context).copyWith(
                      color: AppColors.textPrimary,
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
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            '선택하세요',
            style: AppTextStyles.inputLabel(context).copyWith(
              color: AppColors.textDisabled,
            ),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? AppColors.primary : AppColors.textDisabled,
          ),
          items: [
            DropdownMenuItem(
              value: 'single',
              child: Text(
                '단일 발주',
                style: AppTextStyles.inputLabel(context).copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'multi',
              child: Text(
                '다중 발주',
                style: AppTextStyles.inputLabel(context).copyWith(
                  color: AppColors.textPrimary,
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
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: value != null ? AppColors.primary : AppColors.textDisabled,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null
                    ? _dateFormat.format(value)
                    : '날짜를 선택하세요',
                style: AppTextStyles.inputLabel(context).copyWith(
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
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
                style: AppTextStyles.sectionSubtitle(dialogCtx),
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
                            style: AppTextStyles.listTitle(dialogCtx).copyWith(
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
                          onSurface: AppColors.textPrimary,
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
                            color: AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '취소',
                          style: AppTextStyles.inputLabel(dialogCtx).copyWith(
                            fontWeight: FontWeight.w600,
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
                          style: AppTextStyles.inputLabel(dialogCtx).copyWith(
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
  }) async {
    try {
      final fileSize = await image.length();
      if (fileSize > 10 * 1024 * 1024) {
        _removeOptimisticCard(tempId);
        if (mounted) {
          AppBanner.show(context, '파일 크기는 10MB 이하여야 합니다.', type: BannerType.error);
        }
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

        AppBanner.show(context, '$typeLabel 업로드 완료', type: BannerType.success);

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
      if (mounted) {
        AppBanner.show(context, '업로드 중 오류가 발생했습니다.', type: BannerType.error);
      }
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
            color: AppColors.backgroundPrimary,
            border: Border.all(color: AppColors.border),
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
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      side: const BorderSide(color: AppColors.border),
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
                            color: AppColors.border,
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
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
        title: AppBarTitle('거래명세서'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: const [],
      ),
      backgroundColor: AppColors.backgroundPrimary,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _statements.isEmpty
              ? const FlatEmptyState(
                  message: '업로드된 거래명세서가 없습니다',
                  icon: Icons.insert_drive_file_outlined,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadStatements();
                    if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
                  },
                  child: ListView.builder(
                    itemCount: _statements.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const FlatSectionHeader(title: '업로드 목록');
                      }
                      final statement = _statements[index - 1];
                      return _buildStatementRow(statement);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.small(
        key: _uploadFabKey,
        onPressed: _showUploadOptionsMenu,
        backgroundColor: AppColors.primary,
        heroTag: null,
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

  // ── 리스트 행 ───────────────────────────────────────

  void _viewStatement(TransactionStatementSummary statement) {
    if (statement.imageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _StatementImageViewer(statement: statement),
      ),
    );
  }

  Widget _buildStatementRow(TransactionStatementSummary statement) {
    final statusStyle = _statusStyle(statement.status);
    final modeStyle = _modeStyle(statement.statementMode);
    final uploadedAt = _formatDate(statement.uploadedAt);
    final vendorName = statement.vendorName ?? '-';
    final grandTotal = _formatAmount(statement.grandTotal);
    final uploaderName = statement.uploaderName ?? '-';

    return Material(
      color: Colors.white,
      child: InkWell(
      onTap: () => _viewStatement(statement),
      child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 12),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 뱃지 행
          Row(
            children: [
              StatusChip(
                label: modeStyle.label,
                color: modeStyle.foregroundColor,
              ),
              const SizedBox(width: 6),
              StatusChip(
                label: statusStyle.label,
                color: statusStyle.foregroundColor,
              ),
              const Spacer(),
              Text(
                uploadedAt,
                style: AppTextStyles.listSubtitle(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 거래처명
          Text(
            vendorName,
            style: AppTextStyles.listTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // 하단: 금액 + 등록자
          Row(
            children: [
              Text(
                grandTotal,
                style: AppTextStyles.tableCell(context),
              ),
              const Spacer(),
              Text(
                uploaderName,
                style: AppTextStyles.tableCellSub(context),
              ),
            ],
          ),
        ],
      ),
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
          backgroundColor: AppColors.successLight,
          foregroundColor: const Color(0xFF2E7D32),
        );
      case 'rejected':
        return _StatusStyle(
          label: '거부됨',
          icon: Icons.cancel_outlined,
          backgroundColor: AppColors.errorLight,
          foregroundColor: const Color(0xFFD32F2F),
        );
      case 'failed':
        return _StatusStyle(
          label: '실패',
          icon: Icons.error_outline,
          backgroundColor: AppColors.errorLight,
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
          foregroundColor: AppColors.primary,
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

// ── 거래명세서 원본 이미지 뷰어 ─────────────────────────────

class _StatementImageViewer extends StatefulWidget {
  final TransactionStatementSummary statement;

  const _StatementImageViewer({required this.statement});

  @override
  State<_StatementImageViewer> createState() => _StatementImageViewerState();
}

class _StatementImageViewerState extends State<_StatementImageViewer> {
  bool _isPdf = false;
  bool _isLoading = true;
  String? _pdfPath;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final url = widget.statement.imageUrl.toLowerCase();
    _isPdf = url.endsWith('.pdf') || url.contains('.pdf');
    if (_isPdf) {
      _downloadPdf();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.statement.imageUrl));
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'PDF 다운로드 실패 (${response.statusCode})';
          _isLoading = false;
        });
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/statement_${widget.statement.id}.pdf');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) {
        setState(() {
          _pdfPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'PDF를 불러올 수 없습니다';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isPdf ? Colors.white : Colors.black,
      appBar: AppBar(
        title: Text(
          widget.statement.vendorName ?? widget.statement.fileName ?? '거래명세서',
          style: TextStyle(
            color: _isPdf ? AppColors.textPrimary : Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: _isPdf ? Colors.white : Colors.black,
        surfaceTintColor: _isPdf ? Colors.white : Colors.black,
        foregroundColor: _isPdf ? AppColors.textPrimary : Colors.white,
        elevation: 0,
        actions: [
          if (_isPdf && _totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoSheet(context),
            tooltip: '상세정보',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.gray400),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.gray400, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : _isPdf
                  ? _buildPdfView()
                  : _buildImageView(),
    );
  }

  Widget _buildPdfView() {
    if (_pdfPath == null) return const SizedBox.shrink();
    return PDFView(
      filePath: _pdfPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      fitPolicy: FitPolicy.WIDTH,
      onRender: (pages) {
        if (mounted) {
          setState(() => _totalPages = pages ?? 0);
        }
      },
      onPageChanged: (page, total) {
        if (mounted && page != null) {
          setState(() => _currentPage = page);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _errorMessage = 'PDF 렌더링 실패');
        }
      },
    );
  }

  Widget _buildImageView() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          widget.statement.imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 64, color: AppColors.gray400),
              const SizedBox(height: 16),
              Text(
                '이미지를 불러올 수 없습니다',
                style: TextStyle(color: AppColors.gray400, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    final dateFormat = DateFormat('yyyy. MM. dd. HH:mm');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _infoRow(context, '거래처', widget.statement.vendorName ?? '-'),
            _infoRow(context, '합계금액', widget.statement.grandTotal != null
                ? '${NumberFormat('#,##0').format(widget.statement.grandTotal)}원'
                : '-'),
            _infoRow(context, '종류', widget.statement.statementMode == 'receipt'
                ? '입고수량'
                : widget.statement.statementMode == 'monthly'
                    ? '월말결제'
                    : '거래명세서'),
            _infoRow(context, '상태', widget.statement.status),
            _infoRow(context, '업로드일', dateFormat.format(widget.statement.uploadedAt)),
            _infoRow(context, '등록자', widget.statement.uploaderName ?? '-'),
            if (widget.statement.confirmedByName != null)
              _infoRow(context, '확인자', widget.statement.confirmedByName!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.inputLabel(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.gray400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.sectionSubtitle(context).copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
