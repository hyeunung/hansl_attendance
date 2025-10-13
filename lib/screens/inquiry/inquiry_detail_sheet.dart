import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/inquiry_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import 'package:intl/intl.dart';

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
  final _resolutionController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _resolutionController.text = widget.inquiry['resolution_note'] ?? '';
  }

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  /// 상태 업데이트 (완료 처리)
  Future<void> _updateStatus() async {
    setState(() {
      _isUpdating = true;
    });

    final result = await _inquiryService.updateInquiryStatus(
      inquiryId: widget.inquiry['id'],
      status: 'resolved',  // 항상 resolved로 설정
      resolutionNote: _resolutionController.text.trim(),
    );

    setState(() {
      _isUpdating = false;
    });

    if (result['success']) {
      widget.onStatusUpdate(result['data']);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('문의가 완료 처리되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            const Text(
              '이 문의를 삭제하시겠습니까?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '삭제된 문의는 복구할 수 없습니다.',
              style: TextStyle(
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
            child: const Text(
              '취소',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
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
            child: const Text(
              '삭제',
              style: TextStyle(fontWeight: FontWeight.w600),
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

    final result = await _inquiryService.deleteInquiry(widget.inquiry['id']);

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
      case '연차':
        return Icons.beach_access_rounded;
      case '근태':
        return Icons.access_time_rounded;
      case '오류':
        return Icons.error_outline_rounded;
      case '기타':
        return Icons.more_horiz_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(widget.inquiry['created_at']);
    final dateStr = DateFormat('yyyy년 MM월 dd일 HH:mm').format(createdAt);
    final status = widget.inquiry['status'] ?? 'open';
    final statusLabel = InquiryService.getStatusLabel(status);
    final statusColor = Color(InquiryService.getStatusColor(status));

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
                    _getIconForType(widget.inquiry['inquiry_type'] ?? '기타'),
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
                      const Text(
                        '문의 상세',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 삭제 버튼 (권한 있을 때만)
                FutureBuilder<Map<String, dynamic>>(
                  future: _inquiryService.canDeleteInquiry(widget.inquiry['id']),
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
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '#${widget.inquiry['id']}',
                                style: const TextStyle(
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
                                value: widget.inquiry['user_name'] ?? '알 수 없음',
                              ),
                              _buildInfoItem(
                                icon: Icons.category_outlined,
                                label: '문의 유형',
                                value: InquiryService.getInquiryTypeLabel(
                                  widget.inquiry['inquiry_type'],
                                ),
                              ),
                              if (widget.inquiry['user_email'] != null &&
                                  widget.inquiry['user_email'].toString().isNotEmpty)
                                _buildInfoItem(
                                  icon: Icons.email_outlined,
                                  label: '이메일',
                                  value: widget.inquiry['user_email'],
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

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
                            const Text(
                              '제목',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.inquiry['subject'] ?? '제목 없음',
                          style: const TextStyle(
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
                            const Text(
                              '문의 내용',
                              style: TextStyle(
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
                            widget.inquiry['message'] ?? '내용 없음',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1C1C1E),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 관리자 답변 섹션
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.reply_rounded,
                                size: 18,
                                color: const Color(0xFF007AFF),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '답변 작성',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _resolutionController,
                            maxLines: 5,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1C1C1E),
                            ),
                            decoration: InputDecoration(
                              hintText: '답변을 입력하세요',
                              hintStyle: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFFAEAEB2),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E5EA),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E5EA),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            onChanged: (value) {
                              setState(() {});  // 버튼 상태 업데이트
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.inquiry['resolution_note'] != null &&
                      widget.inquiry['resolution_note'].toString().isNotEmpty) ...[
                    // 일반 사용자에게 답변 표시
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF007AFF).withValues(alpha: 0.05),
                            const Color(0xFF0051D5).withValues(alpha: 0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          // 답변 헤더
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.support_agent_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '관리자 답변',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF007AFF),
                                        ),
                                      ),
                                      if (widget.inquiry['handled_by'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '담당자: ${widget.inquiry['handled_by']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (widget.inquiry['resolved_at'] != null)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 20,
                                    color: Color(0xFF34C759),
                                  ),
                              ],
                            ),
                          ),
                          // 답변 내용
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              widget.inquiry['resolution_note'],
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1C1C1E),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 하단 버튼 (관리자만)
          if (widget.isAdmin)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(
                    color: Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _resolutionController.text.trim().isEmpty
                      ? null
                      : AppColors.primaryGradient,
                  color: _resolutionController.text.trim().isEmpty
                      ? const Color(0xFFE5E5EA)
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _resolutionController.text.trim().isEmpty
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_isUpdating || _resolutionController.text.trim().isEmpty)
                        ? null
                        : _updateStatus,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: _isUpdating
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: _resolutionController.text.trim().isEmpty
                                      ? const Color(0xFF8E8E93)
                                      : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '답변 완료',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _resolutionController.text.trim().isEmpty
                                        ? const Color(0xFF8E8E93)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
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