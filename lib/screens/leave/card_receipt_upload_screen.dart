import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../providers/leave_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/common/notification_banner_widget.dart';

class CardReceiptUploadScreen extends StatefulWidget {
  const CardReceiptUploadScreen({super.key});

  @override
  State<CardReceiptUploadScreen> createState() =>
      _CardReceiptUploadScreenState();
}

class _CardReceiptUploadScreenState extends State<CardReceiptUploadScreen> {
  List<Map<String, dynamic>> _cardUsages = [];
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;
  final double rValue = 14;

  @override
  void initState() {
    super.initState();
    _loadCardUsages();
    _loadVendors();
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

  Future<void> _loadVendors() async {
    try {
      final data = await Supabase.instance.client
          .from('vendors')
          .select('id, vendor_name')
          .order('vendor_name');
      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle('영수증 업로드'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      backgroundColor: AppColors.backgroundPrimary,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cardUsages.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadCardUsages();
                    if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
                  },
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
              color: AppColors.textDisabled,
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 16)),
            Text(
              '업로드 가능한 카드 사용 건이 없습니다.',
              style: AppTextStyles.sectionSubtitle(context).copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
            Text(
              '웹에서 출장/카드 신청이 승인된 후\n여기에서 영수증을 업로드할 수 있습니다.',
              style: AppTextStyles.emptyState(context).copyWith(
                color: AppColors.textDisabled,
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
      decoration: AppDecorations.defaultCard,
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
                            ? AppColors.biztrip
                            : AppColors.success)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 8),
                    ),
                  ),
                  child: Icon(
                    bt != null ? Icons.flight_takeoff : Icons.credit_card,
                    size: ResponsiveUtils.iconSize(context, 18),
                    color: bt != null
                        ? AppColors.biztrip
                        : AppColors.success,
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
                    style: AppTextStyles.buttonPrimary(context).copyWith(
                      color: AppColors.textPrimary,
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
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.spacing(context, 10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '카드: $cardNumber',
                    style: AppTextStyles.tableCellSub(context),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                  Text(
                    '기간: $startDate ~ $endDate',
                    style: AppTextStyles.tableCellSub(context),
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
                    color: AppColors.success,
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                  Text(
                    '업로드된 영수증: ${receipts.map((r) => r['receipt_url']).toSet().length}건',
                    style: AppTextStyles.inputLabel(context).copyWith(
                      color: AppColors.success,
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
                    style: AppTextStyles.sectionSubtitle(context).copyWith(
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
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
    XFile? selectedImage;
    // 다중 품목 리스트
    List<Map<String, TextEditingController>> itemRows = [
      _createItemRow(),
    ];

    void calcTotal(int idx, StateSetter setModalState) {
      final qty = int.tryParse(itemRows[idx]['quantity']!.text) ?? 0;
      final price = int.tryParse(itemRows[idx]['unit_price']!.text.replaceAll(',', '')) ?? 0;
      if (qty > 0 && price > 0) {
        setModalState(() {
          itemRows[idx]['total_amount']!.text = (qty * price).toString();
        });
      }
    }

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
                          color: AppColors.gray400,
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 2),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    Text(
                      '영수증 업로드',
                      style: AppTextStyles.appBarTitle(context).copyWith(
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

                    // 사용처 (업체 검색 + 직접 입력)
                    _buildMerchantField(merchantController, setModalState),

                    SizedBox(height: ResponsiveUtils.spacing(context, 16)),

                    // 품목 목록 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              '품목 목록',
                              style: AppTextStyles.buttonPrimary(context).copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacing(context, 8),
                                vertical: ResponsiveUtils.spacing(context, 2),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                              child: Text(
                                '${itemRows.length}개',
                                style: AppTextStyles.cardBody(context).copyWith(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              itemRows.add(_createItemRow());
                            });
                          },
                          icon: Icon(Icons.add, size: ResponsiveUtils.iconSize(context, 16)),
                          label: Text('추가', style: AppTextStyles.cardBody(context).copyWith(color: AppColors.info)),
                          style: TextButton.styleFrom(foregroundColor: AppColors.info),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),

                    // 품목 행들
                    ...itemRows.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final row = entry.value;
                      return _buildItemCard(
                        idx: idx,
                        row: row,
                        totalItems: itemRows.length,
                        setModalState: setModalState,
                        calcTotal: () => calcTotal(idx, setModalState),
                        onDelete: () {
                          setModalState(() {
                            for (final c in row.values) {
                              c.dispose();
                            }
                            itemRows.removeAt(idx);
                          });
                        },
                      );
                    }),

                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedImage == null
                            ? null
                            : () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          disabledBackgroundColor: AppColors.gray400,
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
                          style: AppTextStyles.buttonPrimary(context),
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

    // 필수 검증: 사용처, 첫번째 비고(사용이유), 최소 1개 품목
    final merchant = merchantController.text.trim();
    if (merchant.isEmpty) {
      if (mounted) AppBanner.show(context, '사용처는 필수입니다.', type: BannerType.error);
      return;
    }
    if (itemRows.isEmpty || itemRows[0]['remark']!.text.trim().isEmpty) {
      if (mounted) AppBanner.show(context, '첫번째 품목의 비고(사용이유)는 필수입니다.', type: BannerType.error);
      return;
    }

    // 유효한 품목 필터링 (품명 + 합계 필수)
    final validItems = <Map<String, dynamic>>[];
    for (final row in itemRows) {
      final itemName = row['item_name']!.text.trim();
      final totalAmount = row['total_amount']!.text.trim().replaceAll(',', '');
      if (itemName.isNotEmpty && totalAmount.isNotEmpty) {
        validItems.add({
          'item_name': itemName,
          'specification': row['specification']!.text.trim(),
          'quantity': int.tryParse(row['quantity']!.text.trim()) ?? 1,
          'unit_price': int.tryParse(row['unit_price']!.text.trim().replaceAll(',', '')) ?? 0,
          'total_amount': int.tryParse(totalAmount) ?? 0,
          'remark': row['remark']!.text.trim(),
        });
      }
    }

    if (validItems.isEmpty) {
      if (mounted) AppBanner.show(context, '최소 1개 품목의 품명과 합계를 입력해주세요.', type: BannerType.error);
      return;
    }

    await _uploadReceipt(
      cardUsageId: cardUsage['id'].toString(),
      imagePath: selectedImage!.path,
      merchantName: merchant,
      items: validItems,
    );

    // dispose controllers
    merchantController.dispose();
    for (final row in itemRows) {
      for (final c in row.values) {
        c.dispose();
      }
    }
  }

  Map<String, TextEditingController> _createItemRow() {
    return {
      'item_name': TextEditingController(),
      'specification': TextEditingController(),
      'quantity': TextEditingController(text: '1'),
      'unit_price': TextEditingController(),
      'total_amount': TextEditingController(),
      'remark': TextEditingController(),
    };
  }

  Widget _buildMerchantField(TextEditingController controller, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: '사용처(업체) ',
            style: AppTextStyles.inputLabel(context).copyWith(color: AppColors.textSecondary),
            children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))],
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 6)),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable.empty();
            final query = textEditingValue.text.toLowerCase();
            return _vendors
                .map((v) => v['vendor_name'] as String)
                .where((name) => name.toLowerCase().contains(query));
          },
          onSelected: (String selection) {
            controller.text = selection;
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            // sync with our controller
            textController.addListener(() {
              controller.text = textController.text;
            });
            return TextField(
              controller: textController,
              focusNode: focusNode,
              style: AppTextStyles.sectionSubtitle(context).copyWith(fontWeight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: '업체 검색 또는 직접 입력',
                hintStyle: AppTextStyles.cardBody(context).copyWith(color: AppColors.gray400),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 16),
                  vertical: ResponsiveUtils.spacing(context, 14),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildItemCard({
    required int idx,
    required Map<String, TextEditingController> row,
    required int totalItems,
    required StateSetter setModalState,
    required VoidCallback calcTotal,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 10)),
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 14)),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
        border: Border.all(color: AppColors.gray400.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (번호 + 삭제)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '품목 ${idx + 1}',
                style: AppTextStyles.inputLabel(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (totalItems > 1)
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.close, size: ResponsiveUtils.iconSize(context, 18), color: AppColors.error),
                ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 10)),
          // 품목명 + 규격
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  controller: row['item_name']!,
                  label: '품목명 *',
                  hint: '입력',
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Expanded(
                child: _buildCompactField(
                  controller: row['specification']!,
                  label: '규격',
                  hint: '입력',
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 8)),
          // 수량 + 단가 + 합계
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildCompactField(
                  controller: row['quantity']!,
                  label: '수량',
                  hint: '1',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => calcTotal(),
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Expanded(
                flex: 2,
                child: _buildCompactField(
                  controller: row['unit_price']!,
                  label: '단가',
                  hint: '0',
                  suffix: '원',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => calcTotal(),
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Expanded(
                flex: 2,
                child: _buildCompactField(
                  controller: row['total_amount']!,
                  label: '합계 *',
                  hint: '0',
                  suffix: '원',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 8)),
          // 비고(사용이유)
          _buildCompactField(
            controller: row['remark']!,
            label: idx == 0 ? '비고(사용이유) *' : '비고',
            hint: idx == 0 ? '사용이유' : '선택사항',
          ),
        ],
      ),
    );
  }

  Widget _buildCompactField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffix,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.cardBody(context).copyWith(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 4)),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: AppTextStyles.cardBody(context).copyWith(fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            hintStyle: AppTextStyles.cardBody(context).copyWith(color: AppColors.gray400, fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              borderSide: BorderSide(color: AppColors.gray400.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              borderSide: BorderSide(color: AppColors.gray400.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              borderSide: BorderSide(color: AppColors.info),
            ),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 12),
              vertical: ResponsiveUtils.spacing(context, 10),
            ),
          ),
        ),
      ],
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
            border: Border.all(color: AppColors.gray400),
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
                color: AppColors.info,
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Text(
                label,
                style: AppTextStyles.listTitle(context).copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadReceipt({
    required String cardUsageId,
    required String imagePath,
    required String merchantName,
    required List<Map<String, dynamic>> items,
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
      request.fields['merchant_name'] = merchantName;
      request.fields['items'] = jsonEncode(items);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        if (mounted) {
          AppBanner.show(context, '영수증이 업로드되었습니다. (${items.length}개 품목)', type: BannerType.success);
        }
        await _loadCardUsages();
      } else {
        throw Exception('업로드 실패: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        AppBanner.show(context, '업로드 중 오류: $e', type: BannerType.error);
      }
    }
  }
}
