import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/receipt_upload_service.dart';
import '../../utils/responsive_utils.dart';
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
  String _selectedCategory = '전체';
  final List<String> _categories = ['전체', '일반', '출장', '회의비', '기타'];
  
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
      
      if (userEmail == null) return;

      final List<Map<String, dynamic>> data;
      
      if (_selectedCategory == '전체') {
        data = await _supabase
            .from('purchase_receipts')
            .select()
            .eq('uploaded_by', userEmail)
            .order('uploaded_at', ascending: false);
      } else {
        data = await _supabase
            .from('purchase_receipts')
            .select()
            .eq('uploaded_by', userEmail)
            .eq('category', _selectedCategory)
            .order('uploaded_at', ascending: false);
      }
      
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

  /// 새 영수증 업로드
  Future<void> _uploadNewReceipt() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userEmail = userProvider.email;
    
    if (userEmail == null) return;

    // 카테고리 선택 다이얼로그
    final selectedCategory = await _showCategoryDialog();
    if (selectedCategory == null) return;

    // 설명 입력 다이얼로그
    final description = await _showDescriptionDialog();

    try {
      final url = await ReceiptUploadService.showIndependentReceiptUploadDialog(
        context: context,
        userEmail: userEmail,
        description: description,
        category: selectedCategory,
      );

      if (url != null) {
        // 업로드 성공
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 영수증 업로드 완료'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReceipts(); // 목록 새로고침
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업로드 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 카테고리 선택 다이얼로그
  Future<String?> _showCategoryDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories.skip(1).map((category) => // '전체' 제외
            ListTile(
              title: Text(category),
              onTap: () => Navigator.pop(context, category),
            ),
          ).toList(),
        ),
      ),
    );
  }

  /// 설명 입력 다이얼로그
  Future<String?> _showDescriptionDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영수증 설명'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '영수증에 대한 설명을 입력하세요 (선택사항)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

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
  void _viewReceipt(Map<String, dynamic> receipt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ReceiptDetailScreen(receipt: receipt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영수증 관리'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 카테고리 필터
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((category) {
                final isSelected = category == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    _loadReceipts();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                              Icons.receipt_long,
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
                            return _buildReceiptCard(receipt);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadNewReceipt,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final uploadedAt = DateTime.parse(receipt['uploaded_at']);
    final category = receipt['category'] ?? '일반';
    final description = receipt['description'] ?? '';
    final fileName = receipt['file_name'] ?? 'receipt.jpg';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 영수증 썸네일
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            
            // 영수증 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${uploadedAt.year}.${uploadedAt.month.toString().padLeft(2, '0')}.${uploadedAt.day.toString().padLeft(2, '0')}',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 액션 버튼들
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.blue),
                  onPressed: () => _viewReceipt(receipt),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteReceipt(receipt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 영수증 상세 화면
class _ReceiptDetailScreen extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const _ReceiptDetailScreen({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(receipt['file_name'] ?? 'Receipt'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 영수증 이미지
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  receipt['receipt_image_url'],
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
            _buildInfoRow('파일명', receipt['file_name'] ?? ''),
            _buildInfoRow('카테고리', receipt['category'] ?? '일반'),
            _buildInfoRow('설명', receipt['description'] ?? '없음'),
            _buildInfoRow('업로드 일시', _formatDateTime(receipt['uploaded_at'])),
            _buildInfoRow('업로드자', receipt['uploaded_by_name'] ?? ''),
            _buildInfoRow('파일 크기', _formatFileSize(receipt['file_size'])),
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
    final dt = DateTime.parse(dateTime);
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}