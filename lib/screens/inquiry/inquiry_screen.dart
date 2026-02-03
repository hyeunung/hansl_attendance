import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/inquiry_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'inquiry_detail_sheet.dart';

class _QuantityChangeRow {
  _QuantityChangeRow({this.itemId, this.newQuantity = ''});
  String? itemId;
  String newQuantity;
}

class _PriceChangeRow {
  _PriceChangeRow({
    this.itemId,
    this.changeType = 'unit_price',
    this.newValue = '',
  });
  String? itemId;
  String changeType;
  String newValue;
}

/// 문의하기 화면
/// - 일반 직원: 문의 작성 + 내 문의 내역
/// - app_admin: 모든 문의 내역 + 답변/상태 변경
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen>
    with SingleTickerProviderStateMixin {
  final InquiryService _inquiryService = InquiryService();
  TabController? _tabController;

  // 권한 관련
  bool _isAdmin = false;
  bool _isLoadingAuth = true;

  // 문의 작성 폼
  String? _selectedType;
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _pendingImages = [];

  // 발주 연동 상태
  DateTime? _purchaseStartDate;
  DateTime? _purchaseEndDate;
  bool _isSearchingPurchase = false;
  List<Map<String, dynamic>> _purchaseRequests = [];
  Map<String, dynamic>? _selectedPurchase;
  DateTime? _requestedDeliveryDate;
  List<_QuantityChangeRow> _quantityChangeRows = [];
  List<_PriceChangeRow> _priceChangeRows = [];

  // 문의 목록
  List<Map<String, dynamic>> _inquiries = [];
  bool _isLoadingInquiries = true;

  // 실시간 구독
  dynamic _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // 권한 확인
    final isAdmin = await _inquiryService.isAppAdmin();

    // 탭 컨트롤러 초기화 (관리자는 탭 불필요, 일반은 2개 탭)
    if (!isAdmin) {
      _tabController = TabController(length: 2, vsync: this);
    }

    setState(() {
      _isAdmin = isAdmin;
      _isLoadingAuth = false;
    });

    // 문의 목록 로드
    await _loadInquiries();

    // 실시간 구독 설정
    _setupRealtimeSubscription();
  }

  /// 문의 목록 로드
  Future<void> _loadInquiries() async {
    setState(() {
      _isLoadingInquiries = true;
    });

    final allInquiries = await _inquiryService.getInquiries();
    final inquiries = List<Map<String, dynamic>>.from(allInquiries);
    
    // 정렬 적용
    _sortInquiriesList(inquiries);

    setState(() {
      _inquiries = inquiries;
      _isLoadingInquiries = false;
    });
  }

  /// 실시간 구독 설정
  void _setupRealtimeSubscription() {
    _realtimeSubscription = _inquiryService.subscribeToInquiryUpdates(
      onUpdate: (updatedInquiry) {
        // 업데이트된 문의 반영
        setState(() {
          final index = _inquiries.indexWhere(
            (i) => i['id'] == updatedInquiry['id'],
          );
          if (index != -1) {
            // 이전 상태 저장 (업데이트 전에!)
            final previousInquiry = Map<String, dynamic>.from(_inquiries[index]);
            
            // 업데이트 적용
            _inquiries[index] = updatedInquiry;
            
            // 업데이트 후 재정렬
            _sortInquiries();

            // app_admin이 아닌 모든 사용자: 문의가 resolved 상태가 되면 알림
            if (!_isAdmin && 
                updatedInquiry['status'] == 'resolved' &&
                previousInquiry['status'] != 'resolved') {
              _showNotification('문의가 완료 처리되었습니다.');
            }
          }
        });
      },
    );
  }

  /// 문의 목록 정렬 (리스트 직접)
  void _sortInquiriesList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      // 완료되지 않은 문의 우선 (open/in_progress)
      final statusA = (a['status'] ?? 'open').toString();
      final statusB = (b['status'] ?? 'open').toString();
      final completedA = statusA == 'resolved' || statusA == 'closed';
      final completedB = statusB == 'resolved' || statusB == 'closed';

      if (completedA != completedB) {
        return completedA ? 1 : -1;
      }
      
      // 같은 상태라면 최신순으로 정렬
      final dateA = DateTime.parse(a['created_at']);
      final dateB = DateTime.parse(b['created_at']);
      return dateB.compareTo(dateA); // 최신이 앞으로
    });
  }

  /// 문의 목록 정렬 (인스턴스 변수)
  void _sortInquiries() {
    _sortInquiriesList(_inquiries);
  }

  /// 알림 표시
  void _showNotification(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 문의 제출
  Future<void> _submitInquiry() async {
    final selectedType = _selectedType;
    if (selectedType == null || selectedType.isEmpty) {
      _showError('문의 유형을 선택해주세요.');
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showError('내용을 입력해주세요.');
      return;
    }

    final requiresPurchase = _requiresPurchaseType(selectedType);
    if (requiresPurchase && _selectedPurchase == null) {
      _showError('발주요청을 선택해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final typeLabel = InquiryService.getInquiryTypeLabel(selectedType);
    final autoSubject = typeLabel.isNotEmpty ? typeLabel : '문의';

    final uploadedAttachments = <SupportAttachment>[];
    for (final img in _pendingImages) {
      final bytes = await img.readAsBytes();
      final result = await _inquiryService.uploadAttachment(
        originalFileName: img.name,
        contentType: _guessImageContentType(img.name),
        bytes: bytes,
      );
      if (result['success'] != true || result['data'] == null) {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
        _showError(result['error']?.toString() ?? '첨부 업로드에 실패했습니다.');
        return;
      }
      uploadedAttachments.add(result['data'] as SupportAttachment);
    }

    final summaryLines = <String>[];
    Map<String, dynamic>? inquiryPayload;
    String purchaseInfo = '';
    String finalMessage = message;

    final selectedPurchase = _selectedPurchase;
    final selectedItems = _getSelectedPurchaseItems();
    final numberFormat = NumberFormat.decimalPattern('ko_KR');

    if (selectedType == 'delivery_date_change') {
      if (_requestedDeliveryDate == null) {
        setState(() => _isSubmitting = false);
        _showError('변경 입고일을 입력해주세요.');
        return;
      }

      final currentDateText = selectedPurchase?['delivery_request_date'] != null
          ? _formatDate(DateTime.parse(selectedPurchase!['delivery_request_date']))
          : '-';
      final requestedDateText = _formatDate(_requestedDeliveryDate);

      inquiryPayload = {
        'requested_date': requestedDateText,
        'current_date': selectedPurchase?['delivery_request_date'],
      };
      summaryLines.add('현재 입고요청일: $currentDateText');
      summaryLines.add('변경 입고일: $requestedDateText');
    }

    if (selectedType == 'quantity_change') {
      final activeRows = _quantityChangeRows
          .where((row) => (row.itemId ?? '').isNotEmpty || row.newQuantity.trim().isNotEmpty)
          .toList();
      if (activeRows.isEmpty) {
        setState(() => _isSubmitting = false);
        _showError('수량 변경할 품목을 추가해주세요.');
        return;
      }

      final itemsPayload = <Map<String, dynamic>>[];
      for (final row in activeRows) {
        if ((row.itemId ?? '').isEmpty || row.newQuantity.trim().isEmpty) {
          setState(() => _isSubmitting = false);
          _showError('수량 변경 항목을 모두 입력해주세요.');
          return;
        }
        final newQuantity = int.tryParse(row.newQuantity.trim());
        if (newQuantity == null) {
          setState(() => _isSubmitting = false);
          _showError('변경 수량이 올바르지 않습니다.');
          return;
        }

        final target = selectedItems.firstWhere(
          (item) => item['id'].toString() == row.itemId,
          orElse: () => {},
        );
        if (target.isEmpty) {
          setState(() => _isSubmitting = false);
          _showError('선택한 품목을 찾을 수 없습니다.');
          return;
        }

        itemsPayload.add({
          'item_id': target['id'].toString(),
          'line_number': target['line_number'],
          'item_name': target['item_name'],
          'specification': target['specification'],
          'current_quantity': target['quantity'],
          'new_quantity': newQuantity,
        });

        summaryLines.add(
          '${target['line_number'] ?? '-'}번 ${target['item_name']} '
          '(${target['specification'] ?? '-'}) '
          '${target['quantity'] ?? 0} → $newQuantity',
        );
      }

      inquiryPayload = {'items': itemsPayload};
    }

    if (selectedType == 'price_change') {
      final activeRows = _priceChangeRows
          .where((row) => (row.itemId ?? '').isNotEmpty || row.newValue.trim().isNotEmpty)
          .toList();
      if (activeRows.isEmpty) {
        setState(() => _isSubmitting = false);
        _showError('단가/합계 금액 변경할 품목을 추가해주세요.');
        return;
      }

      final itemsPayload = <Map<String, dynamic>>[];
      for (final row in activeRows) {
        if ((row.itemId ?? '').isEmpty || row.newValue.trim().isEmpty) {
          setState(() => _isSubmitting = false);
          _showError('단가/합계 금액 변경 항목을 모두 입력해주세요.');
          return;
        }
        final newValue = num.tryParse(row.newValue.trim());
        if (newValue == null) {
          setState(() => _isSubmitting = false);
          _showError('변경 금액이 올바르지 않습니다.');
          return;
        }

        final target = selectedItems.firstWhere(
          (item) => item['id'].toString() == row.itemId,
          orElse: () => {},
        );
        if (target.isEmpty) {
          setState(() => _isSubmitting = false);
          _showError('선택한 품목을 찾을 수 없습니다.');
          return;
        }

        final quantity = (target['quantity'] as num?) ?? 0;
        final currentUnitPrice = (target['unit_price_value'] as num?) ?? 0;
        final currentAmount = (target['amount_value'] as num?) ?? 0;
        final changeType = row.changeType;

        final payloadItem = <String, dynamic>{
          'item_id': target['id'].toString(),
          'line_number': target['line_number'],
          'item_name': target['item_name'],
          'specification': target['specification'],
          'current_unit_price': currentUnitPrice,
          'current_amount': currentAmount,
          'change_type': changeType,
        };

        if (changeType == 'amount') {
          final newAmount = newValue;
          payloadItem['new_amount'] = newAmount;
          summaryLines.add(
            '${target['line_number'] ?? '-'}번 ${target['item_name']} '
            '(${target['specification'] ?? '-'}) '
            '합계 ${numberFormat.format(currentAmount)} → ${numberFormat.format(newAmount)}',
          );
        } else {
          final newUnitPrice = newValue;
          final newAmount = quantity * newUnitPrice;
          payloadItem['new_unit_price'] = newUnitPrice;
          payloadItem['new_amount'] = newAmount;
          summaryLines.add(
            '${target['line_number'] ?? '-'}번 ${target['item_name']} '
            '(${target['specification'] ?? '-'}) '
            '단가 ${numberFormat.format(currentUnitPrice)} → ${numberFormat.format(newUnitPrice)} '
            '합계 ${numberFormat.format(currentAmount)} → ${numberFormat.format(newAmount)}',
          );
        }

        itemsPayload.add(payloadItem);
      }

      inquiryPayload = {'items': itemsPayload};
    }

    if (selectedType == 'delete') {
      inquiryPayload = {'reason': message};
    }

    if (selectedPurchase != null) {
      final itemsText = selectedItems
          .asMap()
          .entries
          .map(
            (entry) {
              final item = entry.value;
              final line = item['line_number'] ?? (entry.key + 1);
              final name = item['item_name'] ?? '';
              final spec = item['specification'] ?? '-';
              final qty = item['quantity'] ?? 0;
              return '- $line. $name ($spec) ${qty}개';
            },
          )
          .join('\n');

      final orderNumber = selectedPurchase['purchase_order_number'] ?? '(승인대기)';
      purchaseInfo = '발주번호: $orderNumber\n'
          '업체: ${selectedPurchase['vendor_name'] ?? ''}\n'
          '요청자: ${selectedPurchase['requester_name'] ?? ''}\n'
          '요청일: ${selectedPurchase['request_date'] ?? selectedPurchase['created_at'] ?? '-'}\n'
          '품목:\n$itemsText';
    }

    final messageSections = [message];
    if (summaryLines.isNotEmpty) {
      messageSections.add('[요청 상세]\n${summaryLines.join('\n')}');
    }
    if (purchaseInfo.isNotEmpty) {
      messageSections.add('[관련 발주 정보]\n$purchaseInfo');
    }
    finalMessage = messageSections.join('\n\n');

    final result = await _inquiryService.createInquiry(
      inquiryType: selectedType,
      subject: autoSubject,
      message: finalMessage,
      userName: userProvider.name ?? '알 수 없음',
      userEmail: userProvider.email ?? '',
      purchaseRequestId: selectedPurchase?['id'] as int?,
      purchaseOrderNumber: selectedPurchase?['purchase_order_number']?.toString(),
      purchaseInfo: purchaseInfo.isEmpty ? null : purchaseInfo,
      attachments: uploadedAttachments,
      inquiryPayload: inquiryPayload,
      includeInitialMessage: false,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (result['success']) {
      _messageController.clear();
      setState(() {
        _selectedType = null;
        _pendingImages = [];
        _purchaseRequests = [];
        _selectedPurchase = null;
        _purchaseStartDate = null;
        _purchaseEndDate = null;
        _requestedDeliveryDate = null;
        _quantityChangeRows = [];
        _priceChangeRows = [];
      });

      await _loadInquiries();
      _tabController?.animateTo(1);
      _showNotification(result['message']);
    } else {
      _showError(result['message']);
    }
  }

  /// 에러 표시
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _requiresPurchaseType(String? type) {
    if (type == null) return false;
    return const {
      'modify',
      'delete',
      'delivery_date_change',
      'quantity_change',
      'price_change',
    }.contains(type);
  }

  List<Map<String, dynamic>> _getSelectedPurchaseItems() {
    final raw = _selectedPurchase?['purchase_request_items'];
    if (raw is! List) return [];
    final items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    items.sort((a, b) {
      final aLine = a['line_number'] ?? 99999;
      final bLine = b['line_number'] ?? 99999;
      return (aLine as num).compareTo(bLine as num);
    });
    return items;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_purchaseStartDate ?? DateTime.now())
        : (_purchaseEndDate ?? _purchaseStartDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2019),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _purchaseStartDate = picked;
        if (_purchaseEndDate != null && _purchaseEndDate!.isBefore(picked)) {
          _purchaseEndDate = picked;
        }
      } else {
        _purchaseEndDate = picked;
      }
    });
  }

  void _handleTypeChanged(String? value) {
    setState(() {
      _selectedType = value;
      if (!_requiresPurchaseType(value)) {
        _purchaseRequests = [];
        _selectedPurchase = null;
        _purchaseStartDate = null;
        _purchaseEndDate = null;
      } else {
        final now = DateTime.now();
        _purchaseStartDate ??= DateTime(now.year, now.month - 2, now.day);
        _purchaseEndDate ??= DateTime(now.year, now.month, now.day);
      }
      _requestedDeliveryDate = null;
      _quantityChangeRows = [];
      _priceChangeRows = [];
    });
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 12),
          vertical: ResponsiveUtils.spacing(context, 12),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8E8E93),
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 6)),
            Text(
              _formatDate(value),
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRequestedDeliveryDate() async {
    if (_selectedPurchase == null) {
      _showError('발주요청을 먼저 선택해주세요.');
      return;
    }
    final initial = _requestedDeliveryDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2019),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _requestedDeliveryDate = picked;
    });
  }

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Row(
      children: [
        Container(
          width: ResponsiveUtils.spacing(context, 4),
          height: ResponsiveUtils.spacing(context, 20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
        Expanded(
          child: Text(
            title,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (required) ...[
          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 8),
              vertical: ResponsiveUtils.spacing(context, 2),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 4),
              ),
            ),
            child: Text(
              '필수',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFF3B30),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedPurchaseSummary(List<Map<String, dynamic>> items) {
    final selected = _selectedPurchase;
    if (selected == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택된 발주',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 8)),
          Text(
            '발주번호: ${selected['purchase_order_number'] ?? '-'}',
            style: ResponsiveUtils.getTextStyle(context, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '업체: ${selected['vendor_name'] ?? '-'}',
            style: ResponsiveUtils.getTextStyle(context, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '요청일: ${selected['request_date'] ?? selected['created_at'] ?? '-'}',
            style: ResponsiveUtils.getTextStyle(context, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (items.isNotEmpty) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            Text(
              '품목',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3C3C43),
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 6)),
            ...items.map((item) {
              final line = item['line_number'] ?? '-';
              final name = item['item_name'] ?? '';
              final spec = item['specification'] ?? '-';
              final qty = item['quantity'] ?? 0;
              return Padding(
                padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 4)),
                child: Text(
                  '$line. $name ($spec) ${qty}개',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    color: const Color(0xFF6E6E73),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('첨부 이미지'),
        SizedBox(height: ResponsiveUtils.spacing(context, 12)),
        Row(
          children: [
            Expanded(
              child: Text(
                '최대 5개, 이미지 파일만 첨부 가능',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 12,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openAttachmentPicker,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('사진 추가'),
            ),
          ],
        ),
        if (_pendingImages.isNotEmpty) ...[
          SizedBox(height: ResponsiveUtils.spacing(context, 8)),
          Wrap(
            spacing: ResponsiveUtils.spacing(context, 8),
            runSpacing: ResponsiveUtils.spacing(context, 8),
            children: _pendingImages.asMap().entries.map((entry) {
              final index = entry.key;
              final img = entry.value;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(img.path),
                      width: ResponsiveUtils.spacing(context, 72),
                      height: ResponsiveUtils.spacing(context, 72),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, size: 18, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _pendingImages.removeAt(index);
                        });
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _searchPurchaseRequests() async {
    final now = DateTime.now();
    final defaultStart = DateTime(now.year, now.month - 2, now.day);
    final defaultEnd = DateTime(now.year, now.month, now.day);
    final startDate = _purchaseStartDate ?? defaultStart;
    final endDate = _purchaseEndDate ?? defaultEnd;

    setState(() {
      _isSearchingPurchase = true;
      _purchaseStartDate = startDate;
      _purchaseEndDate = endDate;
    });

    final result = await _inquiryService.getMyPurchaseRequests(
      startDate: startDate,
      endDate: endDate,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _purchaseRequests =
            List<Map<String, dynamic>>.from(result['data'] as List<dynamic>);
      });
    } else {
      _showError(result['error']?.toString() ?? '발주요청 조회 실패');
    }

    setState(() {
      _isSearchingPurchase = false;
    });
  }

  void _addQuantityChangeRow() {
    setState(() {
      _quantityChangeRows.add(_QuantityChangeRow());
    });
  }

  void _removeQuantityChangeRow(int index) {
    setState(() {
      _quantityChangeRows.removeAt(index);
    });
  }

  void _addPriceChangeRow() {
    setState(() {
      _priceChangeRows.add(_PriceChangeRow());
    });
  }

  void _removePriceChangeRow(int index) {
    setState(() {
      _priceChangeRows.removeAt(index);
    });
  }

  Future<void> _openAttachmentPicker() async {
    if (_pendingImages.length >= 5) {
      _showError('첨부파일은 최대 5개까지 가능합니다.');
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('사진 선택'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라 촬영'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;

      final remaining = 5 - _pendingImages.length;
      final toAdd = files.take(remaining).toList();
      if (toAdd.isEmpty) {
        _showError('첨부파일은 최대 5개까지 가능합니다.');
        return;
      }

      setState(() {
        _pendingImages = [..._pendingImages, ...toAdd];
      });
    } catch (e) {
      _showError('사진 선택 중 오류가 발생했습니다.');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null) return;

      if (_pendingImages.length >= 5) {
        _showError('첨부파일은 최대 5개까지 가능합니다.');
        return;
      }

      setState(() {
        _pendingImages = [..._pendingImages, file];
      });
    } catch (e) {
      _showError('카메라 촬영 중 오류가 발생했습니다.');
    }
  }

  String _guessImageContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _messageController.dispose();
    if (_realtimeSubscription != null) {
      _inquiryService.unsubscribe(_realtimeSubscription);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        centerTitle: true,
        title: Text(
          _isAdmin ? '문의 내역' : '문의하기',
          style: AppTextStyles.appBarTitle(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: _isAdmin
            ? null
            : TabBar(
                controller: _tabController!,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                unselectedLabelStyle: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                tabs: const [
                  Tab(text: '문의 작성'),
                  Tab(text: '내 문의'),
                ],
              ),
      ),
      body: _isAdmin
          ? _buildInquiryList()
          : TabBarView(
              controller: _tabController!,
              children: [_buildInquiryForm(), _buildInquiryList()],
            ),
    );
  }

  /// 문의 작성 폼
  Widget _buildInquiryForm() {
    final canSubmit = !_isSubmitting &&
        (_selectedType?.isNotEmpty ?? false) &&
        _messageController.text.trim().isNotEmpty &&
        (!_requiresPurchaseType(_selectedType) || _selectedPurchase != null);

    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
      child: Column(
        children: [
          // 메인 폼 컨테이너
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: ResponsiveUtils.spacing(context, 10),
                  offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 문의 유형 선택 섹션
                  Row(
                    children: [
                      Container(
                        width: ResponsiveUtils.spacing(context, 4),
                        height: ResponsiveUtils.spacing(context, 20),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '문의 유형',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 16),
                      vertical: ResponsiveUtils.spacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF8F9FA),
                          const Color(0xFFF2F3F5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 12),
                      ),
                      border: Border.all(
                        color: const Color(0xFFE5E5EA),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedType,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF007AFF),
                          size: ResponsiveUtils.iconSize(context, 24),
                        ),
                        hint: Text(
                          '문의 유형을 선택해주세요',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFAEAEB2),
                          ),
                        ),
                        selectedItemBuilder: (_) => InquiryService.getInquiryTypes()
                            .map(
                              (type) => Row(
                                children: [
                                  Icon(
                                    _getIconForType(type['value']!),
                                    size: ResponsiveUtils.iconSize(context, 18),
                                    color: const Color(0xFF007AFF),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                                  Expanded(
                                  child: Text(
                                    type['label'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1C1C1E),
                        ),
                        items: InquiryService.getInquiryTypes()
                            .map(
                              (type) => DropdownMenuItem(
                                value: type['value'],
                                child: Row(
                                  children: [
                                    Icon(
                                      _getIconForType(type['value']!),
                                      size: ResponsiveUtils.iconSize(context, 18),
                                      color: const Color(0xFF007AFF),
                                    ),
                                    SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                                    Text(type['label']!),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          _handleTypeChanged(value);
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveUtils.spacing(context, 24)),

                  if (_requiresPurchaseType(_selectedType)) ...[
                    _buildSectionTitle('발주요청 선택', required: true),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: '시작일',
                            value: _purchaseStartDate,
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                        Expanded(
                          child: _buildDateField(
                            label: '종료일',
                            value: _purchaseEndDate,
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSearchingPurchase ? null : _searchPurchaseRequests,
                        icon: _isSearchingPurchase
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search, size: 18),
                        label: Text(_isSearchingPurchase ? '조회 중...' : '발주요청 조회'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.spacing(context, 12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    if (!_isSearchingPurchase && _purchaseRequests.isEmpty)
                      Container(
                        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '기간을 선택하고 발주요청을 조회해주세요.',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 13,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      )
                    else if (_purchaseRequests.isNotEmpty)
                      SizedBox(
                        height: ResponsiveUtils.spacing(context, 220),
                        child: ListView.separated(
                          itemCount: _purchaseRequests.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                          itemBuilder: (context, index) {
                            final purchase = _purchaseRequests[index];
                            final isSelected = _selectedPurchase?['id'] == purchase['id'];
                            final items = purchase['purchase_request_items'] as List<dynamic>? ?? [];
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedPurchase = purchase;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF007AFF)
                                        : const Color(0xFFE5E5EA),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '발주번호: ${purchase['purchase_order_number'] ?? '(승인대기)'}',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                                    Text(
                                      '업체: ${purchase['vendor_name'] ?? '-'}',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 12,
                                        color: const Color(0xFF6E6E73),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '요청일: ${purchase['request_date'] ?? purchase['created_at'] ?? '-'}',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 12,
                                        color: const Color(0xFF6E6E73),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '품목 ${items.length}건',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 12,
                                        color: const Color(0xFF6E6E73),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    _buildSelectedPurchaseSummary(_getSelectedPurchaseItems()),
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                  ],

                  if (_selectedType == 'delivery_date_change') ...[
                    _buildSectionTitle('입고일 변경 요청', required: true),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    Text(
                      '현재 입고요청일: ${_selectedPurchase?['delivery_request_date'] != null ? _formatDate(DateTime.parse(_selectedPurchase!['delivery_request_date'])) : '-'}',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 12,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    _buildDateField(
                      label: '변경 입고일',
                      value: _requestedDeliveryDate,
                      onTap: _pickRequestedDeliveryDate,
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                  ],

                  if (_selectedType == 'quantity_change') ...[
                    _buildSectionTitle('수량 변경 요청', required: true),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    if (_getSelectedPurchaseItems().isEmpty)
                      Text(
                        '발주요청을 먼저 선택해주세요.',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 13,
                          color: const Color(0xFF8E8E93),
                        ),
                      )
                    else ...[
                      ..._quantityChangeRows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        final items = _getSelectedPurchaseItems();
                        final selectedItem = items.firstWhere(
                          (item) => item['id'].toString() == row.itemId,
                          orElse: () => {},
                        );
                        final currentQuantity = selectedItem.isEmpty
                            ? null
                            : selectedItem['quantity'];
                        final quantityHint = selectedItem.isEmpty
                            ? '현재 수량: -'
                            : '현재 수량: ${currentQuantity ?? '-'}';
                        final itemLabels = items.map((item) {
                          final line = item['line_number'] ?? '-';
                          final name = item['item_name'] ?? '';
                          final spec = item['specification'] ?? '-';
                          return '$line $name ($spec)';
                        }).toList();
                        return Padding(
                          padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 360;
                              final dropdown = DropdownButtonFormField<String>(
                                value: row.itemId,
                                isExpanded: true,
                                selectedItemBuilder: (_) => itemLabels
                                    .map(
                                      (label) => Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    )
                                    .toList(),
                                items: items
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item['id'].toString(),
                                        child: Text(
                                          '${item['line_number'] ?? '-'} ${item['item_name']} (${item['specification'] ?? '-'})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    row.itemId = value;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: '품목',
                                  border: OutlineInputBorder(),
                                ),
                              );

                              final quantityField = TextFormField(
                                initialValue: row.newQuantity,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: '변경 수량',
                                  hintText: quantityHint,
                                  hintStyle: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontSize: 12,
                                    color: const Color(0xFF8E8E93),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  row.newQuantity = value;
                                },
                              );

                              final removeButton = IconButton(
                                onPressed: () => _removeQuantityChangeRow(index),
                                icon: const Icon(Icons.remove_circle_outline),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    dropdown,
                                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                    quantityField,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: removeButton,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(flex: 3, child: dropdown),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                  Expanded(flex: 2, child: quantityField),
                                  removeButton,
                                ],
                              );
                            },
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addQuantityChangeRow,
                          icon: const Icon(Icons.add),
                          label: const Text('품목 추가'),
                        ),
                      ),
                    ],
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                  ],

                  if (_selectedType == 'price_change') ...[
                    _buildSectionTitle('단가/합계 금액 변경 요청', required: true),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    if (_getSelectedPurchaseItems().isEmpty)
                      Text(
                        '발주요청을 먼저 선택해주세요.',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 13,
                          color: const Color(0xFF8E8E93),
                        ),
                      )
                    else ...[
                      ..._priceChangeRows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        final items = _getSelectedPurchaseItems();
                        final selectedItem = items.firstWhere(
                          (item) => item['id'].toString() == row.itemId,
                          orElse: () => {},
                        );
                        final numberFormat = NumberFormat.decimalPattern('ko_KR');
                        final currentUnitPrice = selectedItem.isEmpty
                            ? null
                            : (selectedItem['unit_price_value'] ?? selectedItem['unit_price']);
                        final currentAmount = selectedItem.isEmpty
                            ? null
                            : (selectedItem['amount_value'] ??
                                ((selectedItem['quantity'] ?? 0) *
                                    (selectedItem['unit_price_value'] ?? 0)));
                        final currentUnitPriceLabel = currentUnitPrice == null
                            ? '-'
                            : '${numberFormat.format(currentUnitPrice)}원';
                        final currentAmountLabel = currentAmount == null
                            ? '-'
                            : '${numberFormat.format(currentAmount)}원';
                        final priceHint = row.changeType == 'amount'
                            ? '현재 합계액: $currentAmountLabel'
                            : '현재 단가: $currentUnitPriceLabel';
                        final itemLabels = items.map((item) {
                          final line = item['line_number'] ?? '-';
                          final name = item['item_name'] ?? '';
                          final spec = item['specification'] ?? '-';
                          return '$line $name ($spec)';
                        }).toList();
                        return Padding(
                          padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: row.itemId,
                                isExpanded: true,
                                selectedItemBuilder: (_) => itemLabels
                                    .map(
                                      (label) => Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    )
                                    .toList(),
                                items: items
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item['id'].toString(),
                                        child: Text(
                                          '${item['line_number'] ?? '-'} ${item['item_name']} (${item['specification'] ?? '-'})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    row.itemId = value;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: '품목',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 360;
                                  final changeTypeField = DropdownButtonFormField<String>(
                                    value: row.changeType,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'unit_price',
                                        child: Text('단가'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'amount',
                                        child: Text('합계액'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        row.changeType = value ?? 'unit_price';
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      labelText: '변경 유형',
                                      border: OutlineInputBorder(),
                                    ),
                                  );

                                  final valueField = TextFormField(
                                    initialValue: row.newValue,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: '변경 값',
                                      hintText: priceHint,
                                      hintStyle: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 12,
                                        color: const Color(0xFF8E8E93),
                                      ),
                                      suffixText: '원',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      row.newValue = value;
                                    },
                                  );

                                  final removeButton = IconButton(
                                    onPressed: () => _removePriceChangeRow(index),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        changeTypeField,
                                        SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                        valueField,
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: removeButton,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(flex: 2, child: changeTypeField),
                                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                      Expanded(flex: 3, child: valueField),
                                      removeButton,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addPriceChangeRow,
                          icon: const Icon(Icons.add),
                          label: const Text('품목 추가'),
                        ),
                      ),
                    ],
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                  ],

                  // 내용 입력 섹션
                  Row(
                    children: [
                      Container(
                        width: ResponsiveUtils.spacing(context, 4),
                        height: ResponsiveUtils.spacing(context, 20),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '문의 내용',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 8),
                          vertical: ResponsiveUtils.spacing(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 4),
                          ),
                        ),
                        child: Text(
                          '필수',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF3B30),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 12),
                      ),
                      border: Border.all(
                        color: _messageController.text.isNotEmpty 
                            ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                            : const Color(0xFFE5E5EA),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 8,
                    maxLength: 1000,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        color: const Color(0xFF1C1C1E),
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '문의하실 내용을 자유롭게 작성해주세요.\n\n예시:\n• 앱 사용 중 발생한 오류\n• 기능 개선 제안\n• 사용 방법 문의\n• 기타 불편 사항',
                        hintStyle: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 15,
                          color: const Color(0xFFAEAEB2),
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(
                          ResponsiveUtils.spacing(context, 16),
                        ),
                        counterText: '',
                      ),
                      onChanged: (value) {
                        setState(() {}); // 테두리 색상 업데이트를 위해
                      },
                    ),
                  ),

                  SizedBox(height: ResponsiveUtils.spacing(context, 24)),

                  _buildAttachmentSection(),

                  // 문자 수 카운터
                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_messageController.text.length} / 1000',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 12,
                        color: _messageController.text.length > 900
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFFAEAEB2),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveUtils.spacing(context, 28)),

                  // 제출 버튼
                  Container(
                    width: double.infinity,
                    height: ResponsiveUtils.spacing(context, 56),
                    decoration: BoxDecoration(
                      gradient: canSubmit ? AppColors.primaryGradient : null,
                      color: canSubmit ? null : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 14),
                      ),
                      boxShadow: canSubmit
                          ? [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                                blurRadius: ResponsiveUtils.spacing(context, 12),
                                offset: Offset(0, ResponsiveUtils.spacing(context, 6)),
                              ),
                            ]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canSubmit ? _submitInquiry : null,
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 14),
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? const CupertinoActivityIndicator(
                                  color: Colors.white,
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      color: canSubmit
                                          ? Colors.white
                                          : const Color(0xFF8E8E93),
                                      size: ResponsiveUtils.iconSize(context, 20),
                                    ),
                                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                    Text(
                                      '문의 등록하기',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: canSubmit
                                            ? Colors.white
                                            : const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 도움말 섹션
          SizedBox(height: ResponsiveUtils.spacing(context, 20)),
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: const Color(0xFF8E8E93),
                  size: ResponsiveUtils.iconSize(context, 20),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '빠른 답변을 위한 팁',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF48484A),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                      Text(
                        '• 문제 발생 시간과 상황을 구체적으로 작성\n• 오류 메시지가 있다면 함께 첨부\n• 업무 시간 내 1~2시간 이내 답변',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 13,
                          color: const Color(0xFF8E8E93),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 문의 유형별 아이콘 매핑
  IconData _getIconForType(String type) {
    switch (type) {
      case 'delivery_date_change':
        return Icons.event_available_rounded;
      case 'quantity_change':
        return Icons.format_list_numbered_rounded;
      case 'price_change':
        return Icons.payments_rounded;
      case 'bug':
      case '오류':
        return Icons.error_outline_rounded;
      case 'modify':
      case '수정 요청':
        return Icons.edit_rounded;
      case 'delete':
      case '삭제 요청':
        return Icons.delete_outline_rounded;
      case 'annual_leave':
      case '연차':
        return Icons.beach_access_rounded;
      case 'attendance':
      case '근태':
        return Icons.access_time_rounded;
      case 'other':
      case '기타':
        return Icons.more_horiz_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// 문의 목록
  Widget _buildInquiryList() {
    if (_isLoadingInquiries) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_inquiries.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 40)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF007AFF).withValues(alpha: 0.05),
                      const Color(0xFF0051D5).withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  size: ResponsiveUtils.iconSize(context, 48),
                  color: const Color(0xFF007AFF).withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),
              Text(
                _isAdmin ? '아직 문의가 없습니다' : '작성한 문의가 없습니다',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 8)),
              Text(
                _isAdmin 
                    ? '직원들의 문의가 등록되면 여기에 표시됩니다' 
                    : '문의 작성 탭에서 새로운 문의를 등록해보세요',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  color: const Color(0xFF8E8E93),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInquiries,
      color: const Color(0xFF007AFF),
      child: ListView.builder(
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
        itemCount: _inquiries.length,
        itemBuilder: (context, index) {
          final inquiry = _inquiries[index];
          return _buildInquiryCard(inquiry);
        },
      ),
    );
  }

  /// 문의 카드
  Widget _buildInquiryCard(Map<String, dynamic> inquiry) {
    final createdAt = DateTime.parse(inquiry['created_at']);
    final dateStr = DateFormat('MM/dd HH:mm').format(createdAt);
    final status = inquiry['status'] ?? 'open';
    final statusLabel = InquiryService.getStatusLabel(status);
    final statusColor = Color(InquiryService.getStatusColor(status));
    final isOpen = status == 'open';  // 대기중 상태 체크
    
    // 채팅형 문의로 전환되면서 답변/읽음은 notifications 기반으로 관리됨
    // 리스트 카드에서 NEW 표시를 쓰고 싶다면, 백엔드에서 has_unread_inquiry_message 같은 필드를 내려주도록 확장 가능
    final hasUnreadResponse =
        !_isAdmin && (inquiry['has_unread_inquiry_message'] == true);

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 16),
        ),
        border: Border.all(
          color: isOpen  // 대기중이면 주황색 테두리
              ? const Color(0xFFFF9500).withValues(alpha: 0.3)
              : hasUnreadResponse 
                  ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                  : const Color(0xFFE5E5EA),
          width: isOpen || hasUnreadResponse ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOpen  // 대기중이면 주황색 그림자
                ? const Color(0xFFFF9500).withValues(alpha: 0.1)
                : hasUnreadResponse
                    ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
            blurRadius: ResponsiveUtils.spacing(context, isOpen || hasUnreadResponse ? 8 : 4),
            offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.spacing(context, 16),
          ),
          onTap: () => _showInquiryDetail(inquiry),
          child: Column(
            children: [
              // 상단 헤더 영역
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 16),
                  vertical: ResponsiveUtils.spacing(context, 12),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.05),
                      statusColor.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                    topRight: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                  ),
                ),
                child: Row(
                  children: [
                    // 문의 유형 아이콘
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 8)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 8),
                        ),
                      ),
                      child: Icon(
                        _getIconForType(inquiry['inquiry_type'] ?? '기타'),
                        size: ResponsiveUtils.iconSize(context, 18),
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                    // 상태 뱃지 (답변 알림 통합)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 10),
                        vertical: ResponsiveUtils.spacing(context, 5),
                      ),
                      decoration: BoxDecoration(
                        color: hasUnreadResponse 
                            ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                            : isOpen
                                ? const Color(0xFFFF9500).withValues(alpha: 0.15)  // 대기중이면 주황색
                                : statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOpen && !hasUnreadResponse) ...[  // 대기중이면 시계 아이콘
                            Icon(
                              Icons.schedule_rounded,
                              size: ResponsiveUtils.iconSize(context, 14),
                              color: const Color(0xFFFF9500),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                          ] else ...[
                            Container(
                              width: ResponsiveUtils.spacing(context, 6),
                              height: ResponsiveUtils.spacing(context, 6),
                              decoration: BoxDecoration(
                                color: hasUnreadResponse 
                                    ? const Color(0xFFFF3B30)
                                    : statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                          ],
                          Text(
                            hasUnreadResponse 
                                ? 'NEW 답변' 
                                : isOpen 
                                    ? '답변 대기중'  // 대기중 텍스트 명확하게
                                    : statusLabel,
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasUnreadResponse 
                                  ? const Color(0xFFFF3B30)
                                  : isOpen
                                      ? const Color(0xFFFF9500)  // 대기중이면 주황색
                                      : statusColor,
                            ),
                          ),
                          if (hasUnreadResponse) ...[
                            SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                            Icon(
                              Icons.notification_important_rounded,
                              size: ResponsiveUtils.iconSize(context, 14),
                              color: const Color(0xFFFF3B30),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 날짜
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: ResponsiveUtils.iconSize(context, 14),
                          color: const Color(0xFF8E8E93),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                        Text(
                          dateStr,
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 본문 영역
              Padding(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            inquiry['subject'] ?? '제목 없음',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C1E),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnreadResponse) ...[
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacing(context, 8),
                              vertical: ResponsiveUtils.spacing(context, 3),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 10),
                              ),
                            ),
                            child: Text(
                              'NEW',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // 내용 미리보기
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    Text(
                      inquiry['message'] ?? '',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: const Color(0xFF6E6E73),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 관리자면 작성자 표시
                    if (_isAdmin) ...[
                      SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 10),
                          vertical: ResponsiveUtils.spacing(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: ResponsiveUtils.iconSize(context, 14),
                              color: const Color(0xFF48484A),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                            Flexible(
                              child: Text(
                                inquiry['user_name'] ?? '알 수 없음',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF48484A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 답변 알림은 상태 뱃지에 통합됨 (중복 제거)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 문의 상세 보기
  void _showInquiryDetail(Map<String, dynamic> inquiry) async {
    // 일반 사용자는 해당 문의 알림을 읽음 처리 (notifications 기반)
    if (!_isAdmin) {
      await _inquiryService.markInquiryNotificationsAsRead(inquiry['id']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InquiryDetailSheet(
        inquiry: inquiry,
        isAdmin: _isAdmin,
        onStatusUpdate: (updatedInquiry) {
          // 목록 업데이트
          setState(() {
            final index = _inquiries.indexWhere(
              (i) => i['id'] == updatedInquiry['id'],
            );
            if (index != -1) {
              _inquiries[index] = updatedInquiry;
            }
          });
        },
        onDelete: () {
          // 삭제 후 목록 새로고침
          _loadInquiries();
        },
      ),
    );
  }
}
