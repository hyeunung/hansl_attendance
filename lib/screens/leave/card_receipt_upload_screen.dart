import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../providers/leave_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';

class CardReceiptUploadScreen extends StatefulWidget {
  const CardReceiptUploadScreen({super.key});

  @override
  State<CardReceiptUploadScreen> createState() =>
      _CardReceiptUploadScreenState();
}

class _CardReceiptUploadScreenState extends State<CardReceiptUploadScreen> {
  List<Map<String, dynamic>> _cardUsages = [];
  bool _isLoading = true;
  final double rValue = 14;

  @override
  void initState() {
    super.initState();
    _loadCardUsages();
  }

  Future<void> _loadCardUsages() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<LeaveProvider>(context, listen: false);
      final usages = await provider.fetchMyUploadableCards();
      if (mounted) {
        setState(() {
          _cardUsages = usages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('영수증 업로드', style: AppTextStyles.appBarTitle(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF6F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cardUsages.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCardUsages,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 20),
                      vertical: ResponsiveUtils.spacing(context, 20),
                    ),
                    itemCount: _cardUsages.length,
                    itemBuilder: (context, index) {
                      return _buildCardUsageTile(_cardUsages[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: ResponsiveUtils.iconSize(context, 64),
              color: const Color(0xFFBBBBBB),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 16)),
            Text(
              '업로드 가능한 카드 사용 건이 없습니다.',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF888888),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
            Text(
              '웹에서 출장/카드 신청이 승인된 후\n여기에서 영수증을 업로드할 수 있습니다.',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                color: const Color(0xFFAAAAAA),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardUsageTile(Map<String, dynamic> cardUsage) {
    final bt = cardUsage['business_trips'];
    final tripCode = bt != null ? bt['trip_code'] ?? '' : '';
    final destination = bt != null ? bt['trip_destination'] ?? '' : '';
    final cardNumber = cardUsage['card_number'] ?? '';
    final description = cardUsage['description'] ?? '';
    final startDate = cardUsage['usage_date_start'] ?? '';
    final endDate = cardUsage['usage_date_end'] ?? startDate;
    final receipts = (cardUsage['card_usage_receipts'] as List?) ?? [];

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.spacing(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, rValue),
        ),
        boxShadow: [AppShadows.card],
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.spacing(context, 6),
                  ),
                  decoration: BoxDecoration(
                    color: (bt != null
                            ? const Color(0xFF1976D2)
                            : const Color(0xFF34C759))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 8),
                    ),
                  ),
                  child: Icon(
                    bt != null ? Icons.flight_takeoff : Icons.credit_card,
                    size: ResponsiveUtils.iconSize(context, 18),
                    color: bt != null
                        ? const Color(0xFF1976D2)
                        : const Color(0xFF34C759),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                Expanded(
                  child: Text(
                    bt != null
                        ? '$tripCode · $destination'
                        : description.isNotEmpty
                            ? description
                            : '카드 사용',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: const Color(0xFF222222),
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 12)),
            // 카드번호 / 기간
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 14),
                vertical: ResponsiveUtils.spacing(context, 10),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.spacing(context, 10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '카드: $cardNumber',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      color: const Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                  Text(
                    '기간: $startDate ~ $endDate',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            // 기존 영수증 목록
            if (receipts.isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.spacing(context, 10)),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: ResponsiveUtils.iconSize(context, 16),
                    color: const Color(0xFF34C759),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                  Text(
                    '업로드된 영수증: ${receipts.length}건',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF34C759),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: ResponsiveUtils.spacing(context, 14)),
            // 업로드 버튼
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [AppShadows.button],
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 10),
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showUploadDialog(cardUsage),
                  icon: Icon(
                    Icons.camera_alt,
                    size: ResponsiveUtils.iconSize(context, 18),
                  ),
                  label: Text(
                    '영수증 촬영/업로드',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveUtils.spacing(context, 14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 10),
                      ),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUploadDialog(Map<String, dynamic> cardUsage) async {
    final merchantController = TextEditingController();
    final itemController = TextEditingController();
    final amountController = TextEditingController();
    XFile? selectedImage;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveUtils.spacing(context, 20)),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: ResponsiveUtils.spacing(context, 20),
                right: ResponsiveUtils.spacing(context, 20),
                top: ResponsiveUtils.spacing(context, 16),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들 바
                    Center(
                      child: Container(
                        width: ResponsiveUtils.spacing(context, 40),
                        height: ResponsiveUtils.spacing(context, 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D1D6),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 2),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    Text(
                      '영수증 업로드',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: const Color(0xFF1D1D1F),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    // 이미지 선택 버튼
                    Row(
                      children: [
                        Expanded(
                          child: _imagePickerButton(
                            icon: Icons.camera_alt,
                            label: '카메라',
                            onTap: () async {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 1920,
                                maxHeight: 1920,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setModalState(() => selectedImage = image);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                        Expanded(
                          child: _imagePickerButton(
                            icon: Icons.photo_library,
                            label: '갤러리',
                            onTap: () async {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1920,
                                maxHeight: 1920,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setModalState(() => selectedImage = image);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (selectedImage != null) ...[
                      SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 10),
                        ),
                        child: Image.file(
                          File(selectedImage!.path),
                          height: ResponsiveUtils.spacing(context, 150),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                    _buildInputField(
                      controller: merchantController,
                      label: '사용처',
                      hint: '예: 커피숍, 주유소',
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    _buildInputField(
                      controller: itemController,
                      label: '품명',
                      hint: '예: 점심식사, 주유',
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    _buildInputField(
                      controller: amountController,
                      label: '합계 금액',
                      hint: '예: 15000',
                      suffix: '원',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedImage == null
                            ? null
                            : () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          disabledBackgroundColor: const Color(0xFFD1D1D6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.spacing(context, 16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.spacing(context, 12),
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '업로드',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || selectedImage == null) return;

    await _uploadReceipt(
      cardUsageId: cardUsage['id'].toString(),
      imagePath: selectedImage!.path,
      merchantName: merchantController.text.trim(),
      itemName: itemController.text.trim(),
      totalAmount: amountController.text.trim(),
    );
  }

  Widget _imagePickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 10),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.spacing(context, 14),
          ),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D1D6)),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.spacing(context, 10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: ResponsiveUtils.iconSize(context, 20),
                color: const Color(0xFF007AFF),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Text(
                label,
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffix,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: ResponsiveUtils.getTextStyle(
        context,
        fontSize: 16,
        color: const Color(0xFF1D1D1F),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        labelStyle: ResponsiveUtils.getTextStyle(
          context,
          fontSize: 14,
          color: const Color(0xFF8E8E93),
        ),
        hintStyle: ResponsiveUtils.getTextStyle(
          context,
          fontSize: 15,
          color: const Color(0xFFC7C7CC),
        ),
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.spacing(context, 10),
          ),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 16),
          vertical: ResponsiveUtils.spacing(context, 14),
        ),
      ),
    );
  }

  Future<void> _uploadReceipt({
    required String cardUsageId,
    required String imagePath,
    required String merchantName,
    required String itemName,
    required String totalAmount,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null) throw Exception('인증 세션이 없습니다.');

      final projectId = 'qvhbigvdfyvhoegkhvef';
      final functionUrl =
          'https://$projectId.supabase.co/functions/v1/upload_card_receipt';

      final request = http.MultipartRequest('POST', Uri.parse(functionUrl));
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imagePath,
        contentType: MediaType('image', 'jpeg'),
      ));
      request.fields['card_usage_id'] = cardUsageId;
      request.fields['merchant_name'] =
          merchantName.isNotEmpty ? merchantName : '미입력';
      request.fields['item_name'] =
          itemName.isNotEmpty ? itemName : '미입력';
      request.fields['total_amount'] =
          totalAmount.isNotEmpty ? totalAmount : '0';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('영수증이 업로드되었습니다.'),
              backgroundColor: Color(0xFF34C759),
            ),
          );
        }
        await _loadCardUsages();
      } else {
        throw Exception('업로드 실패: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 중 오류: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }
}
