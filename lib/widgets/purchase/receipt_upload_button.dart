import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/receipt_upload_service.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive_utils.dart';

/// 영수증 업로드 버튼 위젯 (현장결제 항목 전용)
class ReceiptUploadButton extends StatefulWidget {
  final int purchaseRequestId;
  final int itemId;
  final String? currentReceiptUrl;
  final String? paymentCategory; // 현장결제 여부 확인용
  final VoidCallback onUploadComplete;

  const ReceiptUploadButton({
    super.key,
    required this.purchaseRequestId,
    required this.itemId,
    this.currentReceiptUrl,
    this.paymentCategory,
    required this.onUploadComplete,
  });

  @override
  State<ReceiptUploadButton> createState() => _ReceiptUploadButtonState();
}

class _ReceiptUploadButtonState extends State<ReceiptUploadButton> {
  bool _isUploading = false;

  Future<void> _handleUpload() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userEmail = userProvider.email;

    if (userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자 정보를 찾을 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 업로드 다이얼로그 표시 (카메라 or 갤러리)
      final result = await showModalBottomSheet<String?>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF007AFF)),
                title: const Text('카메라로 촬영'),
                onTap: () async {
                  Navigator.pop(context);
                  final url = await ReceiptUploadService.captureAndUploadReceipt(
                    purchaseRequestId: widget.purchaseRequestId,
                    itemId: widget.itemId,
                    userEmail: userEmail,
                  );
                  if (mounted) {
                    Navigator.pop(context, url);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF34C759)),
                title: const Text('갤러리에서 선택'),
                onTap: () async {
                  Navigator.pop(context);
                  final url = await ReceiptUploadService.selectAndUploadReceipt(
                    purchaseRequestId: widget.purchaseRequestId,
                    itemId: widget.itemId,
                    userEmail: userEmail,
                  );
                  if (mounted) {
                    Navigator.pop(context, url);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Color(0xFF8E8E93)),
                title: const Text('취소'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

      if (result != null && mounted) {
        // 업로드 성공
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 영수증이 업로드되었습니다.'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
        widget.onUploadComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    if (widget.currentReceiptUrl == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영수증 삭제'),
        content: const Text('영수증을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploading = true);

    try {
      await ReceiptUploadService.deleteReceipt(
        receiptId: widget.itemId, // 영수증 ID로 변경
        receiptUrl: widget.currentReceiptUrl!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 영수증이 삭제되었습니다.'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
        widget.onUploadComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현장결제가 아니면 표시 안함
    if (widget.paymentCategory != '현장 결제' && widget.paymentCategory != '현장결제') {
      return const SizedBox.shrink();
    }

    if (_isUploading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // 영수증이 이미 있는 경우
    if (widget.currentReceiptUrl != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 영수증 보기 버튼
          IconButton(
            onPressed: () {
              // 이미지 뷰어 표시
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppBar(
                        title: const Text('영수증'),
                        leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Expanded(
                        child: InteractiveViewer(
                          child: Image.network(
                            widget.currentReceiptUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                                    SizedBox(height: 8),
                                    Text('이미지를 불러올 수 없습니다'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt, color: Color(0xFF34C759)),
            tooltip: '영수증 보기',
            iconSize: ResponsiveUtils.iconSize(context, 24),
          ),
          // 영수증 삭제 버튼
          IconButton(
            onPressed: _handleDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30)),
            tooltip: '영수증 삭제',
            iconSize: ResponsiveUtils.iconSize(context, 24),
          ),
        ],
      );
    }

    // 영수증이 없는 경우 - 업로드 버튼
    return IconButton(
      onPressed: _handleUpload,
      icon: const Icon(Icons.camera_alt, color: Color(0xFF007AFF)),
      tooltip: '영수증 촬영',
      iconSize: ResponsiveUtils.iconSize(context, 24),
    );
  }
}

