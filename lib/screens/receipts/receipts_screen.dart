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
import '../../theme/app_text_theme.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../../widgets/shared/flat_section.dart';

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

  /// 영수증 목록 로드 (웹앱과 동일 패턴: purchase_receipts + receipt_ocr_jobs/results 별도 조회 후 merge)
  Future<void> _loadReceipts() async {
    try {
      setState(() => _isLoading = true);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.email;

      if (userEmail == null) return;

      // 1단계: purchase_receipts 기본 데이터 조회 (OCR 컬럼은 별도 테이블)
      final data = await _supabase
          .from('purchase_receipts')
          .select('id, receipt_image_url, file_name, file_size, uploaded_by, uploaded_by_name, uploaded_at, memo, is_printed, printed_at, printed_by, printed_by_name, group_id')
          .order('uploaded_at', ascending: false);

      final baseReceipts = List<Map<String, dynamic>>.from(data);

      if (baseReceipts.isEmpty) {
        if (mounted) {
          setState(() {
            _receipts = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2단계: receipt_ocr_jobs + receipt_ocr_results 에서 OCR 데이터 조회
      final receiptIds = baseReceipts.map((r) => r['id']).toList();
      Map<String, Map<String, dynamic>> ocrByReceiptId = {};
      try {
        final ocrJobs = await _supabase
            .from('receipt_ocr_jobs')
            .select('source_receipt_id, status, created_at, receipt_ocr_results(merchant_name, item_name, payment_date, quantity, unit_price, total_amount)')
            .inFilter('source_receipt_id', receiptIds)
            .order('created_at', ascending: false);

        for (final job in List<Map<String, dynamic>>.from(ocrJobs)) {
          final sourceId = job['source_receipt_id']?.toString() ?? '';
          if (sourceId.isEmpty || ocrByReceiptId.containsKey(sourceId)) continue;
          final results = job['receipt_ocr_results'];
          final result = results is List ? (results.isNotEmpty ? results[0] : null) : results;
          ocrByReceiptId[sourceId] = {
            'ocr_status': job['status'],
            'ocr_merchant_name': result?['merchant_name'],
            'ocr_item_name': result?['item_name'],
            'ocr_payment_date': result?['payment_date'],
            'ocr_quantity': result?['quantity'],
            'ocr_unit_price': result?['unit_price'],
            'ocr_total_amount': result?['total_amount'],
          };
        }
      } catch (_) {
        // OCR 조회 실패해도 기본 영수증 목록은 표시
      }

      // 3단계: merge
      final merged = baseReceipts.map((receipt) {
        final ocr = ocrByReceiptId[receipt['id']?.toString() ?? ''];
        if (ocr != null) {
          return {...receipt, ...ocr};
        }
        return receipt;
      }).toList();

      if (mounted) {
        setState(() {
          _receipts = merged;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppBanner.show(context, '영수증 로드 실패: $e', type: BannerType.error);
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
        AppBanner.show(context, '이미지 선택 실패: $e', type: BannerType.error);
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
                      side: const BorderSide(color: AppColors.border),
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
                          const Divider(height: 1, color: AppColors.border),
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
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.inputLabel(context).copyWith(
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
                      style: AppTextStyles.sectionSubtitle(context),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: isUploading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.textDisabled),
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
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '다시 선택',
                          style: AppTextStyles.inputLabel(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
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
                                  AppBanner.show(context, '이미지를 선택해주세요.', type: BannerType.error);
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
                            : Text(
                                '업로드',
                                style: AppTextStyles.inputLabel(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
            color: AppColors.backgroundPrimary,
            border: Border.all(color: AppColors.border),
          ),
          child: imageFiles.isEmpty
              ? Center(
                  child: Text(
                    '선택된 이미지가 없습니다',
                    style: AppTextStyles.cardCaption(context),
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
            style: AppTextStyles.sectionHeader(context).copyWith(
              fontSize: ResponsiveUtils.fontSize(context, 12),
            ),
          ),
        ],
        const SizedBox(height: 12),
        
        // 메모 입력
        Text(
          '메모 (선택사항)',
          style: AppTextStyles.sectionHeader(context).copyWith(
            fontSize: ResponsiveUtils.fontSize(context, 12),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: memoController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '영수증에 대한 메모를 입력하세요',
            hintStyle: AppTextStyles.compactLabel(context).copyWith(
              fontSize: ResponsiveUtils.fontSize(context, 12),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
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
              Text(
                '업로드 중...',
                style: AppTextStyles.compactLabel(context).copyWith(
                  fontSize: ResponsiveUtils.fontSize(context, 12),
                  color: AppColors.textSecondary,
                ),
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
        AppBanner.show(context, '✅ 영수증이 업로드되었습니다.', type: BannerType.success);
        _loadReceipts(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        AppBanner.show(context, '업로드 실패: $e', type: BannerType.error);
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

  // _selectImage and _buildUploadOption removed (unused, replaced by unified upload modal)

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
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
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

      AppBanner.show(context, '✅ 영수증 삭제 완료', type: BannerType.success);
      _loadReceipts(); // 목록 새로고침
    } catch (e) {
      AppBanner.show(context, '삭제 실패: $e', type: BannerType.error);
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
        title: AppBarTitle('영수증 관리'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundPrimary,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receipts.isEmpty
              ? const FlatEmptyState(
                  message: '업로드된 영수증이 없습니다',
                  icon: Icons.insert_drive_file_outlined,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadReceipts();
                    if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
                  },
                  child: ListView.builder(
                    itemCount: _receipts.length + 2, // header + table header + items
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return FlatSectionHeader(
                          title: '${DateTime.now().year}',
                          trailing: '${_receipts.length}건',
                        );
                      }
                      if (index == 1) {
                        return _buildTableHeader();
                      }
                      final receipt = _receipts[index - 2];
                      return _buildReceiptCard(receipt, index - 2);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.small(
        key: _uploadFabKey,
        onPressed: _showUploadOptionsMenu,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload, color: Colors.white, size: 20),
      ),
    );
  }

  /// 테이블 헤더 (업로드일 | 결제일 | 거래처 | 품명 | 합계)
  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 16),
        vertical: ResponsiveUtils.spacing(context, 10),
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text('업로드일', style: AppTextStyles.tableHeader(context)),
          ),
          SizedBox(
            width: 52,
            child: Text('결제일', style: AppTextStyles.tableHeader(context)),
          ),
          Expanded(
            flex: 2,
            child: Text('거래처', style: AppTextStyles.tableHeader(context)),
          ),
          Expanded(
            flex: 2,
            child: Text('품명', style: AppTextStyles.tableHeader(context)),
          ),
          SizedBox(
            width: 70,
            child: Text('합계', style: AppTextStyles.tableHeader(context), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt, int index) {
    final uploadedAt = DateTime.parse(receipt['uploaded_at']).toLocal();

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final purchaseRole = userProvider.employee?['purchase_role'];
        final canDelete = UserRoleHelper.isAppAdmin(purchaseRole);

        final content = _buildReceiptRow(receipt, uploadedAt);

        if (canDelete) {
          return Dismissible(
            key: Key('receipt_${receipt['id']}_$index'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('영수증 삭제', style: AppTextStyles.cardTitle(context)),
                  content: Text('정말로 이 영수증을 삭제하시겠습니까?', style: AppTextStyles.cardBody(context)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('취소', style: AppTextStyles.cardBody(context).copyWith(color: AppColors.textSecondary)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('삭제', style: AppTextStyles.cardBody(context).copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) => _deleteReceipt(receipt),
            background: Container(
              color: AppColors.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
            ),
            child: content,
          );
        } else {
          return content;
        }
      },
    );
  }

  Widget _buildReceiptRow(Map<String, dynamic> receipt, DateTime uploadedAt) {
    final paymentDate = receipt['ocr_payment_date'] as String?;
    final merchant = receipt['ocr_merchant_name'] as String? ?? '-';
    final itemName = receipt['ocr_item_name'] as String? ?? '-';
    final totalAmount = receipt['ocr_total_amount'];

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _viewReceipt(receipt),
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
          child: Row(
            children: [
              // 업로드일
              SizedBox(
                width: 52,
                child: Text(
                  _formatShortDate(uploadedAt),
                  style: AppTextStyles.tableHeader(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // 결제일
              SizedBox(
                width: 52,
                child: Text(
                  _formatPaymentDate(paymentDate),
                  style: AppTextStyles.tableHeader(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // 거래처
              Expanded(
                flex: 2,
                child: Text(
                  merchant,
                  style: AppTextStyles.listTitle(context).copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 품명
              Expanded(
                flex: 2,
                child: Text(
                  itemName,
                  style: AppTextStyles.tableCellSub(context).copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 합계
              SizedBox(
                width: 70,
                child: Text(
                  _formatKrw(totalAmount),
                  style: AppTextStyles.tableCell(context).copyWith(fontSize: 13),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatShortDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatPaymentDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      // OCR 결과가 날짜 형식이 아닐 수 있음
      if (dateStr.length > 5) return dateStr.substring(0, 5);
      return dateStr;
    }
  }

  String _formatKrw(dynamic amount) {
    if (amount == null) return '-';
    final num value = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
    if (value == 0) return '-';
    // 천 단위 콤마
    final parts = value.toInt().toString().split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write(',');
      buffer.write(parts[i]);
    }
    return buffer.toString();
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
        AppBanner.show(context, '인쇄 실패: $e', type: BannerType.error);
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
              color: AppColors.success,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              '인쇄 완료',
              style: AppTextStyles.sectionTitle(context),
            ),
          ],
        ),
        content: Text(
          '이 영수증의 인쇄상태를 완료 처리 하시겠습니까?',
          style: AppTextStyles.sectionSubtitle(context).copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: AppTextStyles.sectionSubtitle(context).copyWith(
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              '완료',
              style: AppTextStyles.sectionSubtitle(context).copyWith(
                color: Colors.white,
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
        AppBanner.show(context, '사용자 정보를 불러올 수 없습니다', type: BannerType.error);
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
        AppBanner.show(context, '✅ 인쇄 완료 처리되었습니다', type: BannerType.success);

        // 인쇄 완료 처리 후 메인 화면에 새로고침 신호 전달
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppBanner.show(context, '인쇄 완료 처리 실패: $e', type: BannerType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receipt['file_name'] ?? 'Receipt'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✅ 인쇄 완료',
                            style: AppTextStyles.sectionSubtitle(context).copyWith(
                              color: AppColors.success,
                            ),
                          ),
                          if (widget.receipt['printed_by_name'] != null)
                            Text(
                              '${widget.receipt['printed_by_name']}님이 인쇄함',
                              style: AppTextStyles.compactLabel(context).copyWith(
                                fontSize: ResponsiveUtils.fontSize(context, 12),
                                color: AppColors.success,
                              ),
                            ),
                          if (widget.receipt['printed_at'] != null)
                            Text(
                              _formatDateTime(widget.receipt['printed_at']),
                              style: AppTextStyles.compactLabel(context).copyWith(
                                fontSize: ResponsiveUtils.fontSize(context, 12),
                                color: AppColors.success,
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
                    color: AppColors.gray200,
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