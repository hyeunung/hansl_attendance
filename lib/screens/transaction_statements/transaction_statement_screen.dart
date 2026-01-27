import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/transaction_statement_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';

class TransactionStatementScreen extends StatefulWidget {
  const TransactionStatementScreen({super.key});

  @override
  State<TransactionStatementScreen> createState() =>
      _TransactionStatementScreenState();
}

class _TransactionStatementScreenState
    extends State<TransactionStatementScreen> {
  final GlobalKey _uploadFabKey = GlobalKey();
  final _dateFormat = DateFormat('yyyy. MM. dd.');
  final _amountFormat = NumberFormat('#,##0');
  List<TransactionStatementSummary> _statements = [];
  bool _isLoading = true;
  bool _isUploading = false;
  RealtimeChannel? _statementChannel;
  Timer? _realtimeDebounce;
  bool _isRealtimeRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadStatements();
    _setupRealtimeSubscription();
  }

  Future<void> _loadStatements({bool showLoading = true}) async {
    try {
      if (showLoading) {
        setState(() => _isLoading = true);
      }
      final data = await TransactionStatementService.fetchStatements();
      if (mounted) {
        setState(() {
          _statements = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (showLoading) {
          setState(() => _isLoading = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래명세서 목록을 불러오지 못했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupRealtimeSubscription() {
    final client = Supabase.instance.client;
    _statementChannel = client
        .channel('transaction_statements_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transaction_statements',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .subscribe();
  }

  void _handleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_isRealtimeRefreshing) return;
      _isRealtimeRefreshing = true;
      Future.microtask(() async {
        try {
          if (!mounted) return;
          await _loadStatements(showLoading: false);
        } finally {
          _isRealtimeRefreshing = false;
        }
      });
    });
  }

  @override
  void dispose() {
    if (_statementChannel != null) {
      Supabase.instance.client.removeChannel(_statementChannel!);
      _statementChannel = null;
    }
    _realtimeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _startUploadFlow(ImageSource source) async {
    if (_isUploading) return;
    try {
      debugPrint('[TransactionStatement] start upload flow: $source');
      final image = await TransactionStatementService.pickImage(source);
      if (image == null) {
        debugPrint('[TransactionStatement] image pick canceled');
        return;
      }
      await _showPreviewDialog(image);
    } catch (e) {
      debugPrint('[TransactionStatement] image pick error: $e');
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

  Future<void> _showPreviewDialog(XFile image) async {
    bool isUploading = false;
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
                      '거래명세서 확인',
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
                  File(image.path),
                  isUploading,
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
                                setState(() => isUploading = true);
                                try {
                                  await _uploadStatementFromPreview(image);
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

  Widget _buildImagePreview(
    File imageFile,
    bool isUploading,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Image.file(
                    imageFile,
                    width: constraints.maxWidth,
                    fit: BoxFit.fitWidth,
                  ),
                );
              },
            ),
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

  Future<void> _showUploadOptionsMenu() async {
    debugPrint(
      '[TransactionStatement] upload menu pressed (isUploading=$_isUploading)',
    );
    if (_isUploading) return;
    final renderBox =
        _uploadFabKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(context, rootNavigator: true)
        .overlay
        ?.context
        .findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) {
      debugPrint(
        '[TransactionStatement] upload menu abort: renderBox=$renderBox overlay=$overlay',
      );
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
    debugPrint(
      '[TransactionStatement] menu geometry: top=$menuTop bottom=$menuBottom left=$menuLeft width=$menuWidth height=$menuHeight',
    );

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
                  debugPrint(
                    '[TransactionStatement] upload menu dismissed (outside tap)',
                  );
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
    debugPrint('[TransactionStatement] upload menu result: $selected');
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

  Future<void> _uploadStatementFromPreview(XFile image) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final fileSize = await image.length();
      if (fileSize > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('파일 크기는 10MB 이하여야 합니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final uploaderName = (userProvider.employee?['name'] as String?) ??
          userProvider.name ??
          '알 수 없음';

      final result = await TransactionStatementService.uploadStatement(
        imageFile: image,
        uploaderName: uploaderName,
      );

      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _statements = [
            TransactionStatementSummary(
              id: result.statementId,
              imageUrl: result.imageUrl,
              fileName: null,
              status: 'processing',
              uploadedAt: now,
              uploaderName: uploaderName,
              statementDate: null,
              vendorName: null,
              grandTotal: null,
              confirmedByName: null,
            ),
            ..._statements.where(
              (item) => item.id != result.statementId,
            ),
          ];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 거래명세서가 업로드되었습니다.'),
            backgroundColor: Color(0xFF34C759),
          ),
        );

        await _loadStatements(showLoading: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('업로드 중 오류가 발생했습니다.'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '거래명세서',
          style: ResponsiveUtils.getTextStyle(
            context,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: const [],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Text(
              '업로드 목록',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _statements.isEmpty
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
                              '업로드된 거래명세서가 없습니다',
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
                        onRefresh: _loadStatements,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _statements.length,
                          itemBuilder: (context, index) {
                            final statement = _statements[index];
                            return _buildStatementCard(statement);
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
        child: _isUploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStatementCard(TransactionStatementSummary statement) {
    final statusStyle = _statusStyle(statement.status);
    final uploadedAt = _formatDate(statement.uploadedAt);
    final statementDate = _formatDate(statement.statementDate);
    final vendorName = statement.vendorName ?? '-';
    final grandTotal = _formatAmount(statement.grandTotal);
    final uploaderName = statement.uploaderName ?? '-';
    final confirmedByName = statement.confirmedByName ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        statusStyle.icon,
                        size: 14,
                        color: statusStyle.foregroundColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusStyle.label,
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusStyle.foregroundColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('업로드일', uploadedAt),
            _buildInfoRow('명세서일', statementDate),
            _buildInfoRow('거래처명', vendorName),
            _buildInfoRow('합계금액', grandTotal),
            _buildInfoRow('등록자', uploaderName),
            _buildInfoRow('확정자', confirmedByName),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return _dateFormat.format(dateTime);
  }

  String _formatAmount(num? amount) {
    if (amount == null) return '-';
    return '${_amountFormat.format(amount)}원';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 13,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'pending':
        return _StatusStyle(
          label: '대기중',
          icon: Icons.schedule,
          backgroundColor: const Color(0xFFF2F4F7),
          foregroundColor: const Color(0xFF667085),
        );
      case 'processing':
        return _StatusStyle(
          label: '처리중',
          icon: Icons.autorenew,
          backgroundColor: const Color(0xFFE8F1FF),
          foregroundColor: const Color(0xFF2F80ED),
        );
      case 'extracted':
        return _StatusStyle(
          label: '확인필요',
          icon: Icons.info_outline,
          backgroundColor: const Color(0xFFFFF4E5),
          foregroundColor: const Color(0xFFB54708),
        );
      case 'confirmed':
        return _StatusStyle(
          label: '확정됨',
          icon: Icons.check_circle_outline,
          backgroundColor: const Color(0xFFE8F5E9),
          foregroundColor: const Color(0xFF2E7D32),
        );
      case 'rejected':
        return _StatusStyle(
          label: '거부됨',
          icon: Icons.cancel_outlined,
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: const Color(0xFFD32F2F),
        );
      default:
        return _StatusStyle(
          label: status,
          icon: Icons.help_outline,
          backgroundColor: const Color(0xFFF2F4F7),
          foregroundColor: const Color(0xFF667085),
        );
    }
  }
}

class _StatusStyle {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  _StatusStyle({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}
