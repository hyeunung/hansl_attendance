import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../providers/user_provider.dart';
import '../../services/receipt_upload_service.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/user_role_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

/// 영수증 전용 화면
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final GlobalKey _uploadFabKey = GlobalKey();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = true;
  // 카테고리 필터 제거됨
  
  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  /// 영수증 목록 로드
  Future<void> _loadReceipts() async {
    try {
      setState(() => _isLoading = true);
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.email;
      // final purchaseRole = userProvider.employee?['purchase_role'];
      
      if (userEmail == null) return;

      // app_admin, hr, lead_buyer 모두 전체 영수증 조회 가능
      final data = await _supabase
          .from('purchase_receipts')
          .select()
          .order('uploaded_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _receipts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('영수증 로드 실패: $e')),
        );
      }
    }
  }

  /// 통합된 영수증 업로드 모달 (옵션 선택 → 이미지 미리보기 → 메모 입력)

  Future<void> _startUploadFlow(ImageSource source) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final images = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (images.isEmpty) {
          return;
        }
        await _showPreviewDialog(
          images.map((image) => File(image.path)).toList(),
        );
        return;
      }

      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null) {
        return;
      }
      await _showPreviewDialog([File(image.path)]);
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

  Future<void> _showUploadOptionsMenu() async {
    final renderBox =
        _uploadFabKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(context, rootNavigator: true)
        .overlay
        ?.context
        .findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) {
      return;
    }
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
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                },
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
                          _buildUploadMenuItem(
                            icon: Icons.camera_alt_outlined,
                            label: '촬영',
                            height: menuItemHeight,
                            onTap: () =>
                                Navigator.of(context, rootNavigator: true)
                                    .pop(ImageSource.camera),
                          ),
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                          _buildUploadMenuItem(
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
      transitionBuilder: (context, animation, secondaryAnimation, child) => child,
    );
    if (selected != null) {
      await _startUploadFlow(selected);
    }
  }

  Widget _buildUploadMenuItem({
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
              Icon(
                icon,
                size: 18,
                color: const Color(0xFF6B7280),
              ),
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

  Future<void> _showPreviewDialog(List<File> imageFiles) async {
    final memoController = TextEditingController();
    bool isUploading = false;
    final selectedFiles = List<File>.from(imageFiles);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '영수증 확인',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: isUploading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildImagePreview(
                  selectedFiles,
                  memoController,
                  isUploading,
                  onRemove: (index) {
                    setState(() {
                      if (index >= 0 && index < selectedFiles.length) {
                        selectedFiles.removeAt(index);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isUploading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          '다시 선택',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isUploading
                            ? null
                            : () async {
                                if (selectedFiles.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('이미지를 선택해주세요.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                setState(() => isUploading = true);
                                try {
                                  await _uploadReceiptsFromPreview(
                                    selectedFiles,
                                    memoController.text,
                                  );
                                  if (mounted) Navigator.pop(context);
                                } finally {
                                  if (mounted) {
                                    setState(() => isUploading = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '업로드',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 이미지 미리보기 위젯
  Widget _buildImagePreview(
    List<File> imageFiles,
    TextEditingController memoController,
    bool isUploading, {
    required void Function(int index) onRemove,
  }) {
    final isMulti = imageFiles.length > 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이미지 미리보기
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: imageFiles.isEmpty
              ? Center(
                  child: Text(
                    '선택된 이미지가 없습니다',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                )
              : isMulti
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: imageFiles.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    imageFiles[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap:
                                      isUploading ? null : () => onRemove(index),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Image.file(
                              imageFiles.first,
                              width: constraints.maxWidth,
                              fit: BoxFit.fitWidth,
                            ),
                          );
                        },
                      ),
                    ),
        ),
        if (isMulti) ...[
          const SizedBox(height: 8),
          Text(
            '총 ${imageFiles.length}장 선택됨',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
        const SizedBox(height: 12),
        
        // 메모 입력
        Text(
          '메모 (선택사항)',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: memoController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '영수증에 대한 메모를 입력하세요',
            hintStyle: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 12,
              color: Colors.grey[500],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        if (isUploading) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              const Text(
                '업로드 중...',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 업로드된 이미지를 실제로 업로드하는 함수
  Future<void> _uploadReceiptsFromPreview(
    List<File> imageFiles,
    String memo,
  ) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.email;

      if (userEmail == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final groupId = imageFiles.length > 1 ? _generateUuidV4() : null;
      for (final imageFile in imageFiles) {
        await ReceiptUploadService.uploadReceiptFromFile(
          imageFile: imageFile,
          userEmail: userEmail,
          memo: memo.isEmpty ? null : memo,
          groupId: groupId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 영수증이 업로드되었습니다.'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
        _loadReceipts(); // 목록 새로고침
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
      rethrow;
    }
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// Step 2: 이미지 선택
  Future<void> _selectImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      // 이 함수는 더 이상 사용되지 않음 (통합 모달로 대체됨)
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




  /// 업로드 옵션 위젯
  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF9CA3AF),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 메모 입력 다이얼로그

  /// 영수증 삭제
  Future<void> _deleteReceipt(Map<String, dynamic> receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영수증 삭제'),
        content: const Text('정말로 이 영수증을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ReceiptUploadService.deleteReceipt(
        receiptId: receipt['id'],
        receiptUrl: receipt['receipt_image_url'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 영수증 삭제 완료'),
          backgroundColor: Colors.green,
        ),
      );
      _loadReceipts(); // 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 영수증 상세 보기
  void _viewReceipt(Map<String, dynamic> receipt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ReceiptDetailScreen(receipt: receipt),
      ),
    );
    
    // 상세 화면에서 돌아온 후 데이터 새로고침
    if (result == true) {
      _loadReceipts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('영수증 관리', style: ResponsiveUtils.getTextStyle(
          context,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        )),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 년도 표시 (상단 바)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Text(
              '${DateTime.now().year}',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          
          // 영수증 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _receipts.isEmpty
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
                              '업로드된 영수증이 없습니다',
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
                        onRefresh: _loadReceipts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _receipts.length,
                          itemBuilder: (context, index) {
                            final receipt = _receipts[index];
                            return _buildReceiptCard(receipt, index);
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
        child: const Icon(Icons.upload, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt, int index) {
    // 한국 시간대(UTC+9)로 변환하여 표시
    final uploadedAt = DateTime.parse(receipt['uploaded_at']).toLocal();
    final memo = receipt['memo'] ?? '';
    final fileName = receipt['file_name'] ?? 'receipt.jpg';

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final purchaseRole = userProvider.employee?['purchase_role'];
        final canDelete = UserRoleHelper.isAppAdmin(purchaseRole);

        // app_admin만 스와이프 삭제 가능
        if (canDelete) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Dismissible(
              key: Key('receipt_${receipt['id']}_$index'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      '영수증 삭제',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      '정말로 이 영수증을 삭제하시겠습니까?',
                      style: TextStyle(fontSize: 15),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          '삭제',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) => _deleteReceipt(receipt),
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '삭제',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              child: _buildReceiptCardContent(receipt, uploadedAt, memo, fileName, canDelete),
            ),
          );
        } else {
          // 일반 사용자는 스와이프 삭제 불가
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildReceiptCardContent(receipt, uploadedAt, memo, fileName, canDelete),
          );
        }
       },
     );
   }

   Widget _buildReceiptCardContent(
     Map<String, dynamic> receipt,
     DateTime uploadedAt,
     String memo,
     String fileName,
     bool canDelete,
   ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewReceipt(receipt),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // 인쇄 상태 표시
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    (receipt['is_printed'] == true) 
                        ? Icons.check_circle 
                        : Icons.pending,
                    color: (receipt['is_printed'] == true) 
                        ? Colors.green[600] 
                        : Colors.grey[400],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 18),
                
                // 영수증 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 라벨 (작은 텍스트)
                      Row(
                        children: [
                          Text(
                            '날짜',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 40),
                          Text(
                            '파일명',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // 메인 정보 (한 줄에)
                      Row(
                        children: [
                          // 날짜 (10/27 형태)
                          Text(
                            '${uploadedAt.month}/${uploadedAt.day}',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 파일명
                          Expanded(
                            child: Text(
                              fileName,
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4B5563),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // 메모 (있는 경우)
                      if (memo.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            memo,
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 영수증 상세 화면
class _ReceiptDetailScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;

  const _ReceiptDetailScreen({required this.receipt});

  @override
  State<_ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<_ReceiptDetailScreen> {
  late bool _isPrinted;

  @override
  void initState() {
    super.initState();
    _isPrinted = widget.receipt['is_printed'] ?? false;
  }

  /// 영수증 인쇄 기능 (PDF 인쇄 후 완료 확인 모달)
  Future<void> _printReceipt(BuildContext context) async {
    try {
      // 영수증 이미지 다운로드
      final response = await http.get(Uri.parse(widget.receipt['receipt_image_url']));
      final imageBytes = response.bodyBytes;

      // PDF 생성
      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    '영수증',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Image(image, fit: pw.BoxFit.contain),
                  pw.SizedBox(height: 20),
                  pw.Text('파일명: ${widget.receipt['file_name'] ?? ''}'),
                  pw.Text('메모: ${widget.receipt['memo'] ?? '없음'}'),
                  pw.Text('등록인: ${widget.receipt['uploaded_by_name'] ?? ''}'),
                  pw.Text('업로드 일시: ${_formatDateTime(widget.receipt['uploaded_at'])}'),
                ],
              ),
            );
          },
        ),
      );

      // 인쇄 다이얼로그 표시
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: widget.receipt['file_name'] ?? 'receipt.pdf',
      );

      // 인쇄 다이얼로그가 완료된 후, 아직 인쇄 완료 상태가 아니라면 확인 모달 표시
      if (mounted && !_isPrinted) {
        await _showPrintCompleteDialog();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('인쇄 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 인쇄 완료 확인 모달 표시
  Future<void> _showPrintCompleteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green[600],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              '인쇄 완료',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          '이 영수증의 인쇄상태를 완료 처리 하시겠습니까?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              '완료',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _markAsPrinted();
    }
  }

  /// 인쇄 완료 처리
  Future<void> _markAsPrinted() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employee = userProvider.employee;

      if (employee == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사용자 정보를 불러올 수 없습니다'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 인쇄 완료 상태 업데이트
      await Supabase.instance.client
          .from('purchase_receipts')
          .update({
            'is_printed': true,
            'printed_at': DateTime.now().toUtc().toIso8601String(),
            'printed_by': user?.email,
            'printed_by_name': employee['name'],
          })
          .eq('id', widget.receipt['id']);

      setState(() {
        _isPrinted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 인쇄 완료 처리되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // 인쇄 완료 처리 후 메인 화면에 새로고침 신호 전달
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('인쇄 완료 처리 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receipt['file_name'] ?? 'Receipt'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printReceipt(context),
            tooltip: '인쇄',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            // 인쇄 완료 상태 표시 (인쇄 완료 시)
            if (_isPrinted)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✅ 인쇄 완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                          if (widget.receipt['printed_by_name'] != null)
                            Text(
                              '${widget.receipt['printed_by_name']}님이 인쇄함',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                              ),
                            ),
                          if (widget.receipt['printed_at'] != null)
                            Text(
                              _formatDateTime(widget.receipt['printed_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // 영수증 이미지
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.receipt['receipt_image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, size: 50),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 영수증 정보
            _buildInfoRow('파일명', widget.receipt['file_name'] ?? ''),
            // 카테고리 정보 제거됨
            _buildInfoRow('메모', widget.receipt['memo'] ?? '없음'),
            _buildInfoRow('업로드 일시', _formatDateTime(widget.receipt['uploaded_at'])),
            
            // 등록인 정보는 app_admin만 표시
            Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                final purchaseRole = userProvider.employee?['purchase_role'];
                
                if (UserRoleHelper.isAppAdmin(purchaseRole)) {
                  return _buildInfoRow('등록인', widget.receipt['uploaded_by_name'] ?? '');
                }
                return const SizedBox.shrink();
              },
            ),
            
            _buildInfoRow('파일 크기', _formatFileSize(widget.receipt['file_size'])),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return '';
    // 한국 시간대(UTC+9)로 변환하여 표시
    final dt = DateTime.parse(dateTime).toLocal();
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}