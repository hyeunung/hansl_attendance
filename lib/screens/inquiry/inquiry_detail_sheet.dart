import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/inquiry_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

/// 문의 상세 보기 시트
class InquiryDetailSheet extends StatefulWidget {
  final Map<String, dynamic> inquiry;
  final bool isAdmin;
  final Function(Map<String, dynamic>) onStatusUpdate;
  final VoidCallback? onDelete;

  const InquiryDetailSheet({
    super.key,
    required this.inquiry,
    required this.isAdmin,
    required this.onStatusUpdate,
    this.onDelete,
  });

  @override
  State<InquiryDetailSheet> createState() => _InquiryDetailSheetState();
}

class _InquiryDetailSheetState extends State<InquiryDetailSheet> {
  final InquiryService _inquiryService = InquiryService();
  final _chatController = TextEditingController();
  final _detailScrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  RealtimeChannel? _messagesSubscription;
  RealtimeChannel? _notificationsSubscription;

  late Map<String, dynamic> _inquiry;
  List<SupportInquiryMessage> _chatMessages = [];
  bool _isLoadingMessages = true;
  bool _isSending = false;
  bool _isResolving = false;
  List<XFile> _pendingImages = [];
  int _scrollToBottomTries = 0;

  List<SupportAttachment> get _inquiryAttachments {
    final raw = _inquiry['attachments'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .map(SupportAttachment.fromJson)
          .toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _inquiry = Map<String, dynamic>.from(widget.inquiry);
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final inquiryId = (_inquiry['id'] as num?)?.toInt();
    if (inquiryId == null) return;

    // 사용자: 해당 문의 알림 읽음 처리(웹과 동일)
    if (!widget.isAdmin) {
      await _inquiryService.markInquiryNotificationsAsRead(inquiryId);
    }

    await _loadMessages(forceToBottom: true);
    // 드롭다운/시트 첫 오픈에서 스크롤 컨트롤러 attach 타이밍이 늦는 케이스 보강
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBottom());

    // realtime 구독
    _messagesSubscription?.unsubscribe();
    _messagesSubscription = _inquiryService.subscribeToInquiryMessages(
      inquiryId: inquiryId,
      onChange: (_) async {
        await _loadMessages();
      },
    );

    // 보강: notifications 기반으로도 메시지 갱신 (support_inquiry_messages realtime 누락/비활성 대비)
    _notificationsSubscription?.unsubscribe();
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    if (currentEmail != null && currentEmail.isNotEmpty) {
      _notificationsSubscription = Supabase.instance.client
          .channel('inquiry_notifications_$inquiryId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_email',
              value: currentEmail,
            ),
            callback: (payload) async {
              final record = payload.newRecord;
              final type = (record['type'] ?? '').toString();
              if (type != 'inquiry_message' &&
                  type != 'inquiry_resolved' &&
                  type != 'inquiry_response') {
                return;
              }

              final data = record['data'];
              String? inquiryIdStr;
              if (data is Map) {
                inquiryIdStr = (data['inquiryId'] ?? '').toString();
              }
              if (inquiryIdStr == inquiryId.toString()) {
                await _loadMessages();
                // 상태도 바뀌었을 수 있으니 최신 헤더도 갱신
                final detail = await _inquiryService.getInquiryDetail(inquiryId);
                if (detail != null && mounted) {
                  setState(() => _inquiry = Map<String, dynamic>.from(detail));
                  widget.onStatusUpdate(detail);
                }
              }
            },
          )
          .subscribe();
    }
  }

  Future<void> _loadMessages({bool forceToBottom = false}) async {
    final inquiryId = (_inquiry['id'] as num?)?.toInt();
    if (inquiryId == null) return;

    // 스크롤 점프 방지:
    // - 사용자가 바닥 근처에 있으면 새 메시지 수신 시 자동으로 아래로 유지
    // - 그렇지 않으면 현재 위치를 그대로 유지
    final bool stickToBottom = forceToBottom ||
        (_detailScrollController.hasClients &&
        (_detailScrollController.position.maxScrollExtent -
                _detailScrollController.offset) <
            120);
    final double? previousOffset =
        _detailScrollController.hasClients ? _detailScrollController.offset : null;

    setState(() => _isLoadingMessages = true);
    final result = await _inquiryService.getInquiryMessages(inquiryId);

    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as List<SupportInquiryMessage>? ?? [];
      setState(() {
        _chatMessages = data;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (stickToBottom) {
          _ensureBottom();
        } else if (previousOffset != null && _detailScrollController.hasClients) {
          final max = _detailScrollController.position.maxScrollExtent;
          _detailScrollController.jumpTo(previousOffset.clamp(0, max));
        }
      });
    }

    if (mounted) {
      setState(() => _isLoadingMessages = false);
    }
  }

  void _ensureBottom() {
    // 몇 프레임 뒤에 maxScrollExtent가 생기는 케이스가 있어 재시도
    if (_scrollToBottomTries > 8) return;
    if (!_detailScrollController.hasClients) {
      _scrollToBottomTries++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBottom());
      return;
    }
    _scrollToBottomTries = 0;
    _scrollToBottom(animated: false);
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_detailScrollController.hasClients) return;
    final target = _detailScrollController.position.maxScrollExtent;
    if (animated) {
      _detailScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
    // 사용자 UX: 메시지 입력/전송/수신 시 화면이 위→아래로 “스크롤 애니메이션” 되는 느낌을 없애기 위해
    // 필요할 때는 즉시 점프한다.
    _detailScrollController.jumpTo(target);
  }

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    _notificationsSubscription?.unsubscribe();
    _chatController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  bool get _isClosedOrResolved {
    final status = (_inquiry['status'] ?? 'open').toString();
    return status == 'resolved' || status == 'closed';
  }

  Future<void> _openAttachmentPicker() async {
    if (_pendingImages.length >= 5) {
      _showSnack('첨부파일은 최대 5개까지 가능합니다.', isError: true);
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
        _showSnack('첨부파일은 최대 5개까지 가능합니다.', isError: true);
        return;
      }

    setState(() {
        _pendingImages = [..._pendingImages, ...toAdd];
      });
    } catch (e) {
      _showSnack('사진 선택 중 오류가 발생했습니다.', isError: true);
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
        _showSnack('첨부파일은 최대 5개까지 가능합니다.', isError: true);
        return;
      }

    setState(() {
        _pendingImages = [..._pendingImages, file];
      });
    } catch (e) {
      _showSnack('카메라 촬영 중 오류가 발생했습니다.', isError: true);
    }
  }

  String _guessImageContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _sendMessage() async {
    final inquiryId = (_inquiry['id'] as num?)?.toInt();
    if (inquiryId == null) return;

    if (_isClosedOrResolved) {
      _showSnack('완료된 문의에는 메시지를 보낼 수 없습니다.', isError: true);
      return;
    }

    final text = _chatController.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) {
      _showSnack('메시지를 입력하거나 이미지를 첨부해주세요.', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      // 1) 첨부 업로드
      final uploadedAttachments = <SupportAttachment>[];
      for (final img in _pendingImages) {
        final bytes = await img.readAsBytes();
        final result = await _inquiryService.uploadAttachment(
          originalFileName: img.name,
          contentType: _guessImageContentType(img.name),
          bytes: bytes,
        );

        if (result['success'] != true) {
          throw Exception((result['error'] ?? '첨부 업로드 실패').toString());
        }

        uploadedAttachments.add(result['data'] as SupportAttachment);
      }

      // 2) 메시지 insert
      final senderRole = widget.isAdmin ? 'admin' : 'user';
      final res = await _inquiryService.sendInquiryMessage(
        inquiryId: inquiryId,
        senderRole: senderRole,
        message: text,
        attachments: uploadedAttachments,
      );

      if (res['success'] != true) {
        throw Exception((res['error'] ?? '메시지 전송 실패').toString());
      }

      // 관리자 첫 답변이면 open -> in_progress(트리거가 처리하지만 UI도 즉시 반영)
      if (widget.isAdmin && (_inquiry['status'] ?? 'open') == 'open') {
        setState(() {
          _inquiry['status'] = 'in_progress';
        });
      }

      setState(() {
        _chatController.clear();
        _pendingImages = [];
      });

      await _loadMessages(forceToBottom: true);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _resolveFromChat() async {
    if (!widget.isAdmin) return;
    final inquiryId = (_inquiry['id'] as num?)?.toInt();
    if (inquiryId == null) return;
    if (_isClosedOrResolved) return;

    setState(() => _isResolving = true);
    final result = await _inquiryService.resolveInquiry(inquiryId);
    if (!mounted) return;

    setState(() => _isResolving = false);

    if (result['success'] == true) {
      // 최신 문의 상태 가져와서 상위 목록에 반영
      final detail = await _inquiryService.getInquiryDetail(inquiryId);
      if (detail != null) {
        setState(() => _inquiry = Map<String, dynamic>.from(detail));
        widget.onStatusUpdate(detail);
    } else {
        setState(() => _inquiry['status'] = 'resolved');
      }
      _showSnack('문의가 완료 처리되었습니다.');
      await _loadMessages(forceToBottom: true);
    } else {
      _showSnack(
        (result['error'] ?? '완료 처리 실패').toString(),
        isError: true,
      );
    }
  }

  Future<void> _markInProgress() async {
    if (!widget.isAdmin) return;
    final inquiryId = (_inquiry['id'] as num?)?.toInt();
    if (inquiryId == null) return;
    if (_isClosedOrResolved) return;

    final result = await _inquiryService.updateInquiryStatus(
      inquiryId: inquiryId,
      status: 'in_progress',
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final detail = await _inquiryService.getInquiryDetail(inquiryId);
      if (detail != null) {
        setState(() => _inquiry = Map<String, dynamic>.from(detail));
        widget.onStatusUpdate(detail);
      }
      _showSnack('처리중으로 변경되었습니다.');
    } else {
      _showSnack(
        (result['error'] ?? '상태 변경 실패').toString(),
        isError: true,
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
          ),
        );
  }

  Future<void> _openPurchaseDetail() async {
    final purchaseId = (_inquiry['purchase_request_id'] as num?)?.toInt();
    int? resolvedId = purchaseId;
    if (resolvedId == null) {
      final orderNumber = (_inquiry['purchase_order_number'] ?? '').toString();
      if (orderNumber.isNotEmpty) {
        resolvedId = await _inquiryService.getPurchaseRequestIdByOrderNumber(orderNumber);
      }
    }

    if (resolvedId == null) {
      _showSnack('발주 내역을 찾을 수 없습니다.', isError: true);
      return;
    }

    final detail = await _inquiryService.getPurchaseRequestDetail(resolvedId);
    if (detail == null) {
      _showSnack('발주 내역을 불러오지 못했습니다.', isError: true);
      return;
    }

    if (!mounted) return;
    await _showPurchaseDetailDialog(detail);
  }

  Future<void> _showPurchaseDetailDialog(Map<String, dynamic> purchase) async {
    final items = List<Map<String, dynamic>>.from(
      (purchase['purchase_request_items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '발주 상세',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.isAdmin)
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('발주요청 삭제'),
                        content: const Text('발주요청 전체를 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final result = await _inquiryService.deletePurchaseRequestWithInquiryPreserved(
                      (purchase['id'] as num).toInt(),
                    );
                    if (result['success'] == true) {
                      if (mounted) {
                        Navigator.pop(context);
                        _showSnack('발주요청이 삭제되었습니다.');
                      }
                      final inquiryId = (_inquiry['id'] as num?)?.toInt();
                      if (inquiryId != null) {
                        final detail = await _inquiryService.getInquiryDetail(inquiryId);
                        if (detail != null && mounted) {
                          setState(() => _inquiry = Map<String, dynamic>.from(detail));
                          widget.onStatusUpdate(detail);
                        }
                      }
                    } else {
                      _showSnack(result['error']?.toString() ?? '삭제 실패', isError: true);
                    }
                  },
                  child: const Text('전체 삭제'),
                ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '발주번호: ${purchase['purchase_order_number'] ?? '-'}',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '업체명: ${purchase['vendor_name'] ?? '-'}',
                    style: ResponsiveUtils.getTextStyle(context, fontSize: 13),
                  ),
                  Text(
                    '요청자: ${purchase['requester_name'] ?? '-'}',
                    style: ResponsiveUtils.getTextStyle(context, fontSize: 13),
                  ),
                  Text(
                    '요청일: ${purchase['request_date'] ?? purchase['created_at'] ?? '-'}',
                    style: ResponsiveUtils.getTextStyle(context, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['line_number'] ?? '-'}번 ${item['item_name'] ?? ''}',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '규격: ${item['specification'] ?? '-'}',
                            style: ResponsiveUtils.getTextStyle(context, fontSize: 12),
                          ),
                          Text(
                            '수량: ${item['quantity'] ?? '-'}',
                            style: ResponsiveUtils.getTextStyle(context, fontSize: 12),
                          ),
                          Text(
                            '단가: ${(item['unit_price_value'] ?? '-').toString()}',
                            style: ResponsiveUtils.getTextStyle(context, fontSize: 12),
                          ),
                          Text(
                            '금액: ${(item['amount_value'] ?? '-').toString()}',
                            style: ResponsiveUtils.getTextStyle(context, fontSize: 12),
                          ),
                          if (item['remark'] != null && item['remark'].toString().isNotEmpty)
                            Text(
                              '비고: ${item['remark']}',
                              style: ResponsiveUtils.getTextStyle(context, fontSize: 12),
                            ),
                          if (item['link'] != null && item['link'].toString().isNotEmpty)
                            Text(
                              '링크: ${item['link']}',
                              style: ResponsiveUtils.getTextStyle(context, fontSize: 12),
                            ),
                          if (widget.isAdmin)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await _showEditPurchaseItemDialog(item);
                                  },
                                  child: const Text('수정'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('품목 삭제'),
                                        content: const Text('이 품목을 삭제하시겠습니까?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('취소'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('삭제'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    final result = await _inquiryService.deletePurchaseRequestItem(
                                      (item['id'] as num).toInt(),
                                    );
                                    if (result['success'] == true) {
                                      _showSnack('품목이 삭제되었습니다.');
                                    } else {
                                      _showSnack(result['error']?.toString() ?? '삭제 실패',
                                          isError: true);
                                    }
                                  },
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditPurchaseItemDialog(Map<String, dynamic> item) async {
    final nameController = TextEditingController(text: (item['item_name'] ?? '').toString());
    final specController =
        TextEditingController(text: (item['specification'] ?? '').toString());
    final qtyController = TextEditingController(text: (item['quantity'] ?? '').toString());
    final unitController =
        TextEditingController(text: (item['unit_price_value'] ?? '').toString());
    final remarkController = TextEditingController(text: (item['remark'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('품목 수정'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '품명'),
              ),
              TextField(
                controller: specController,
                decoration: const InputDecoration(labelText: '규격'),
              ),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '수량'),
              ),
              TextField(
                controller: unitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '단가'),
              ),
              TextField(
                controller: remarkController,
                decoration: const InputDecoration(labelText: '비고'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final quantity = int.tryParse(qtyController.text.trim());
              final unitPrice = int.tryParse(unitController.text.trim());
              final amount =
                  (quantity != null && unitPrice != null) ? quantity * unitPrice : null;

              final result = await _inquiryService.updatePurchaseRequestItem(
                itemId: (item['id'] as num).toInt(),
                itemName: nameController.text.trim(),
                specification: specController.text.trim(),
                quantity: quantity,
                unitPriceValue: unitPrice,
                amountValue: amount,
                remark: remarkController.text.trim(),
              );
              if (result['success'] == true) {
                if (mounted) Navigator.pop(context);
                _showSnack('품목이 수정되었습니다.');
              } else {
                _showSnack(result['error']?.toString() ?? '수정 실패', isError: true);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('문의 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 문의를 삭제하시겠습니까?',
              style: ResponsiveUtils.getTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '삭제된 문의는 복구할 수 없습니다.',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: ResponsiveUtils.getTextStyle(
                context,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteInquiry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '삭제',
              style: ResponsiveUtils.getTextStyle(context, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 문의 삭제 처리
  Future<void> _deleteInquiry() async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _inquiryService.deleteInquiry(_inquiry['id']);

    // 로딩 닫기
    if (mounted) Navigator.of(context).pop();

    if (result['success']) {
      // 상세 화면 닫기
      if (mounted) Navigator.of(context).pop();
      
      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // 목록 새로고침
      widget.onDelete?.call();
    } else {
      // 에러 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(_inquiry['created_at']);
    final dateStr = DateFormat('yyyy년 MM월 dd일 HH:mm').format(createdAt);
    final status = _inquiry['status'] ?? 'open';
    final statusLabel = InquiryService.getStatusLabel(status);
    final statusColor = Color(InquiryService.getStatusColor(status));

    // 키보드 높이 가져오기
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true, // 키보드가 올라올 때 화면 리사이즈
        body: Column(
        children: [
          // 핸들 바
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(100),
            ),
          ),

          // 상단 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // 아이콘
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF007AFF).withValues(alpha: 0.1),
                        const Color(0xFF0051D5).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForType(_inquiry['inquiry_type'] ?? '기타'),
                    color: const Color(0xFF007AFF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 제목과 날짜
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '문의 상세',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 삭제 버튼 (권한 있을 때만)
                FutureBuilder<Map<String, dynamic>>(
                  future: _inquiryService.canDeleteInquiry(_inquiry['id']),
                  builder: (context, snapshot) {
                    final canDelete = snapshot.data?['canDelete'] == true;
                    
                    return Row(
                      children: [
                        if (canDelete) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              color: const Color(0xFFFF3B30),
                              onPressed: () => _showDeleteConfirmation(context),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: const Color(0xFF3C3C43),
                            onPressed: () => Navigator.pop(context),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 스크롤 가능한 콘텐츠 영역
          Expanded(
            child: SingleChildScrollView(
              controller: _detailScrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 상태 및 정보 카드
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 상태 헤더
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withValues(alpha: 0.08),
                                statusColor.withValues(alpha: 0.03),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      statusLabel,
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (widget.isAdmin && status == 'open')
                                TextButton(
                                  onPressed: _markInProgress,
                                  child: const Text('처리중'),
                                ),
                              Text(
                                '#${_inquiry['id']}',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // 정보 목록
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildInfoItem(
                                icon: Icons.person_outline_rounded,
                                label: '작성자',
                                value: _inquiry['user_name'] ?? '알 수 없음',
                              ),
                              _buildInfoItem(
                                icon: Icons.category_outlined,
                                label: '문의 유형',
                                value: InquiryService.getInquiryTypeLabel(
                                  _inquiry['inquiry_type'],
                                ),
                              ),
                              if (_inquiry['user_email'] != null &&
                                  _inquiry['user_email'].toString().isNotEmpty)
                                _buildInfoItem(
                                  icon: Icons.email_outlined,
                                  label: '이메일',
                                  value: _inquiry['user_email'],
                                  isLast: _inquiry['purchase_order_number'] == null ||
                                      _inquiry['purchase_order_number'].toString().isEmpty,
                                ),
                              if (_inquiry['purchase_order_number'] != null &&
                                  _inquiry['purchase_order_number'].toString().isNotEmpty)
                                _buildInfoItem(
                                  icon: Icons.receipt_long_outlined,
                                  label: '발주번호',
                                  value: _inquiry['purchase_order_number'].toString(),
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if ((_inquiry['purchase_request_id'] != null) ||
                      ((_inquiry['purchase_order_number'] ?? '').toString().isNotEmpty))
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openPurchaseDetail,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('발주 상세 보기'),
                      ),
                    ),

                  // 제목 및 내용 카드
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목
                        Row(
                          children: [
                            Icon(
                              Icons.title_rounded,
                              size: 18,
                              color: const Color(0xFF007AFF),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '제목',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _inquiry['subject'] ?? '제목 없음',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          height: 1,
                          color: const Color(0xFFE5E5EA),
                        ),

                        // 내용
                        Row(
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: 18,
                              color: const Color(0xFF007AFF),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '문의 내용',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5E5EA),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _inquiry['message'] ?? '내용 없음',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 15,
                              color: Color(0xFF1C1C1E),
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (_inquiryAttachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: const Color(0xFF007AFF),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '첨부 이미지',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _inquiryAttachments.map((attachment) {
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      insetPadding: const EdgeInsets.all(16),
                                      child: Image.network(
                                        attachment.url,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    attachment.url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 채팅(대화) 섹션
                    const SizedBox(height: 16),
                  _buildChatPanel(statusLabel: statusLabel, statusColor: statusColor),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          _buildChatInputBar(isKeyboardVisible: isKeyboardVisible),
        ],
      ),
      ),
    );
  }

  Widget _buildChatPanel({
    required String statusLabel,
    required Color statusColor,
  }) {
    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
                        border: Border.all(
          color: statusColor.withValues(alpha: 0.18),
                        ),
                      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                                size: 18,
                  color: Color(0xFF007AFF),
                              ),
                              const SizedBox(width: 8),
                              Text(
                  '대화',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
            // 완료/종료 상태 안내는 입력창 placeholder로 충분하므로
            // 여기(대화 상단)에 중복 안내 박스를 띄우지 않는다.
            if (_isLoadingMessages) ...[
              const SizedBox(height: 8),
              const Center(child: CupertinoActivityIndicator()),
            ] else if (_chatMessages.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '아직 대화가 없습니다.\n아래에서 메시지를 보내보세요.',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 13,
                  color: const Color(0xFF8E8E93),
                  height: 1.35,
                ),
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final m = _chatMessages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildChatMessageBubble(m),
                  );
                },
              ),
            ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildChatMessageBubble(SupportInquiryMessage m) {
    if (m.senderRole == 'system') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            m.message,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ),
      );
    }

    final isUserMsg = m.senderRole == 'user';
    final isMine = widget.isAdmin ? !isUserMsg : isUserMsg;

    final bubbleColor = isMine ? const Color(0xFF007AFF) : Colors.white;
    final textColor = isMine ? Colors.white : const Color(0xFF1C1C1E);
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;

    final timeStr = DateFormat('HH:mm').format(m.createdAt);

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
              padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                border: isMine
                    ? null
                    : Border.all(color: const Color(0xFFE5E5EA), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                  if (m.attachments.isNotEmpty) ...[
                    _buildMessageAttachments(m.attachments, isMine: isMine),
                    if (m.message.trim().isNotEmpty) const SizedBox(height: 10),
                  ],
                  if (m.message.trim().isNotEmpty)
                                      Text(
                      m.message,
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                        fontSize: 14,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
                                        Text(
              timeStr,
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                fontSize: 11,
                color: const Color(0xFFAEAEB2),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
    );
  }

  Widget _buildMessageAttachments(List<SupportAttachment> attachments, {required bool isMine}) {
    final bg = isMine ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF8F9FA);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: attachments.take(5).map((a) {
          return GestureDetector(
            onTap: () => _showFullImage(a.url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                a.url,
                width: 74,
                height: 74,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 74,
                  height: 74,
                  color: const Color(0xFFE5E5EA),
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatInputBar({required bool isKeyboardVisible}) {
    final disabled = _isClosedOrResolved;
    final canSend = !_isSending && !disabled;

    return Container(
              padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: isKeyboardVisible ? 10 : 14,
      ),
      decoration: const BoxDecoration(
                color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingImages.isNotEmpty) ...[
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final img = _pendingImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(img.path),
                            width: 78,
                            height: 78,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
              child: Container(
                decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: InkWell(
                              onTap: disabled
                      ? null
                                  : () => setState(() {
                                        _pendingImages.removeAt(index);
                                      }),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
                              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.image_outlined),
                    color: disabled ? const Color(0xFFAEAEB2) : const Color(0xFF007AFF),
                    onPressed: disabled ? null : _openAttachmentPicker,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _chatController,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !disabled,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: disabled ? '완료된 문의입니다' : '메시지 입력',
                        hintStyle: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 14,
                          color: const Color(0xFFAEAEB2),
                        ),
                      ),
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                        fontSize: 14,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: canSend ? AppColors.primaryGradient : null,
                    color: canSend ? null : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Icon(Icons.send_rounded),
                    color: canSend ? Colors.white : const Color(0xFF8E8E93),
                    onPressed: canSend ? _sendMessage : null,
                  ),
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _isClosedOrResolved ? const Color(0xFFE5E5EA) : const Color(0xFF34C759),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _isResolving
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Icon(Icons.check_circle_outline_rounded),
                      color: _isClosedOrResolved ? const Color(0xFF8E8E93) : Colors.white,
                      onPressed: (_isClosedOrResolved || _isResolving) ? null : _resolveFromChat,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFF8E8E93),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            color: const Color(0xFFE5E5EA).withValues(alpha: 0.5),
          ),
      ],
    );
  }
}