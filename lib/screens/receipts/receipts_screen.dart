import 'dart:io';
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

/// 영수증 전용 화면
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
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
  Future<void> _showUploadOptionsModal() async {
    bool showPreview = false;
    File? selectedImage;
    final memoController = TextEditingController();
    bool isUploading = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: ResponsiveUtils.getScreenWidth(context) * 0.9,
            constraints: BoxConstraints(
              maxHeight: ResponsiveUtils.getScreenHeight(context) * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더 (그라데이션)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        showPreview ? Icons.preview : Icons.upload,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        showPreview ? '영수증 미리보기' : '영수증 업로드',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 내용 영역 (업로드 옵션 or 미리보기)
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: showPreview ? _buildImagePreview(
                        selectedImage!,
                        memoController,
                        isUploading,
                        () async {
                          setState(() => isUploading = true);
                          await _uploadReceiptFromPreview(selectedImage!, memoController.text);
                          if (mounted) Navigator.pop(context);
                        },
                      ) : _buildUploadOptions(
                        (ImageSource source) async {
                          try {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: source,
                              imageQuality: 85,
                              maxWidth: 1920,
                              maxHeight: 1920,
                            );
                            
                            if (image != null) {
                              setState(() {
                                selectedImage = File(image.path);
                                showPreview = true;
                              });
                            }
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
                        },
                      ),
                    ),
                  ),
                ),
                
                // 하단 버튼
                if (!isUploading) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (showPreview) ...[
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  showPreview = false;
                                  selectedImage = null;
                                  memoController.clear();
                                });
                              },
                              child: Text(
                                '다시 선택',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() => isUploading = true);
                                await _uploadReceiptFromPreview(selectedImage!, memoController.text);
                                if (mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                '업로드',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                '취소',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 업로드 옵션 위젯 (카메라/갤러리)
  Widget _buildUploadOptions(Function(ImageSource) onOptionSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '업로드할 영수증을 선택해주세요',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 16,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        
        // 카메라 옵션
        _buildUploadOption(
          icon: Icons.camera_alt,
          title: '카메라로 촬영',
          subtitle: '새로운 영수증을 촬영합니다',
          color: AppColors.primary,
          onTap: () => onOptionSelected(ImageSource.camera),
        ),
        const SizedBox(height: 16),
        
        // 갤러리 옵션
        _buildUploadOption(
          icon: Icons.photo_library,
          title: '갤러리에서 선택',
          subtitle: '저장된 이미지에서 선택합니다',
          color: AppColors.primary,
          onTap: () => onOptionSelected(ImageSource.gallery),
        ),
      ],
    );
  }

  /// 이미지 미리보기 위젯
  Widget _buildImagePreview(
    File imageFile,
    TextEditingController memoController,
    bool isUploading,
    VoidCallback onUpload,
  ) {
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
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // 메모 입력
        Text(
          '메모 (선택사항)',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
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
              fontSize: 14,
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
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  /// 업로드된 이미지를 실제로 업로드하는 함수
  Future<void> _uploadReceiptFromPreview(File imageFile, String memo) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.email;

      if (userEmail == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      await ReceiptUploadService.uploadReceiptFromFile(
        imageFile: imageFile,
        userEmail: userEmail,
        memo: memo.isEmpty ? null : memo,
      );

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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
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
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
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
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadOptionsModal,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload, color: Colors.white),
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