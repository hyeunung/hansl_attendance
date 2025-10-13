import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/inquiry_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import 'package:intl/intl.dart';

/// 문의하기 화면
/// - 일반 직원: 문의 작성 + 내 문의 내역
/// - app_admin: 모든 문의 내역 + 답변/상태 변경
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen>
    with SingleTickerProviderStateMixin {
  final InquiryService _inquiryService = InquiryService();
  TabController? _tabController;

  // 권한 관련
  bool _isAdmin = false;
  bool _isLoadingAuth = true;

  // 문의 작성 폼
  String _selectedType = '연차';
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  // 문의 목록
  List<Map<String, dynamic>> _inquiries = [];
  bool _isLoadingInquiries = true;

  // 실시간 구독
  dynamic _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // 권한 확인
    final isAdmin = await _inquiryService.isAppAdmin();

    // 탭 컨트롤러 초기화 (관리자는 탭 불필요, 일반은 2개 탭)
    if (!isAdmin) {
      _tabController = TabController(length: 2, vsync: this);
    }

    setState(() {
      _isAdmin = isAdmin;
      _isLoadingAuth = false;
    });

    // 문의 목록 로드
    await _loadInquiries();

    // 실시간 구독 설정
    _setupRealtimeSubscription();
  }

  /// 문의 목록 로드
  Future<void> _loadInquiries() async {
    setState(() {
      _isLoadingInquiries = true;
    });

    final inquiries = await _inquiryService.getInquiries();

    setState(() {
      _inquiries = inquiries;
      _isLoadingInquiries = false;
    });
  }

  /// 실시간 구독 설정
  void _setupRealtimeSubscription() {
    _realtimeSubscription = _inquiryService.subscribeToInquiryUpdates(
      onUpdate: (updatedInquiry) {
        // 업데이트된 문의 반영
        setState(() {
          final index = _inquiries.indexWhere(
            (i) => i['id'] == updatedInquiry['id'],
          );
          if (index != -1) {
            _inquiries[index] = updatedInquiry;

            // 답변이 왔을 때 알림 표시
            if (updatedInquiry['resolution_note'] != null &&
                updatedInquiry['resolution_note'].isNotEmpty) {
              _showNotification('답변이 도착했습니다!');
            }
          }
        });
      },
    );
  }

  /// 알림 표시
  void _showNotification(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 문의 제출
  Future<void> _submitInquiry() async {
    if (_messageController.text.trim().isEmpty) {
      _showError('내용을 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // 자동으로 제목 생성 (문의 유형 + 날짜)
    final now = DateTime.now();
    final autoSubject = '[$_selectedType] ${now.month}/${now.day} 문의';

    final result = await _inquiryService.createInquiry(
      inquiryType: _selectedType,
      subject: autoSubject,
      message: _messageController.text.trim(),
      userName: userProvider.name ?? '알 수 없음',
      userEmail: userProvider.email ?? '',
    );

    setState(() {
      _isSubmitting = false;
    });

    if (result['success']) {
      // 폼 초기화
      _messageController.clear();
      setState(() {
        _selectedType = '연차';
      });

      // 목록 새로고침
      await _loadInquiries();

      // 내역 탭으로 이동
      _tabController?.animateTo(1);

      // 성공 메시지
      _showNotification(result['message']);
    } else {
      _showError(result['message']);
    }
  }

  /// 에러 표시
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _messageController.dispose();
    if (_realtimeSubscription != null) {
      _inquiryService.unsubscribe(_realtimeSubscription);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        centerTitle: true,
        title: Text(
          _isAdmin ? '문의 내역' : '문의하기',
          style: AppTextStyles.appBarTitle(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: _isAdmin
            ? null
            : TabBar(
                controller: _tabController!,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                unselectedLabelStyle: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                tabs: const [
                  Tab(text: '문의 작성'),
                  Tab(text: '내 문의'),
                ],
              ),
      ),
      body: _isAdmin
          ? _buildInquiryList()
          : TabBarView(
              controller: _tabController!,
              children: [_buildInquiryForm(), _buildInquiryList()],
            ),
    );
  }

  /// 문의 작성 폼
  Widget _buildInquiryForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
      child: Column(
        children: [
          // 안내 메시지 카드
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF007AFF).withValues(alpha: 0.1),
                  const Color(0xFF0051D5).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 16),
              ),
              border: Border.all(
                color: const Color(0xFF007AFF).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 10)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.spacing(context, 12),
                    ),
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: const Color(0xFF007AFF),
                    size: ResponsiveUtils.iconSize(context, 24),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '어떻게 도와드릴까요?',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                      Text(
                        '궁금한 점이나 불편한 사항을 알려주세요',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 14,
                          color: const Color(0xFF6E6E73),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: ResponsiveUtils.spacing(context, 20)),
          
          // 메인 폼 컨테이너
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: ResponsiveUtils.spacing(context, 10),
                  offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 문의 유형 선택 섹션
                  Row(
                    children: [
                      Container(
                        width: ResponsiveUtils.spacing(context, 4),
                        height: ResponsiveUtils.spacing(context, 20),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '문의 유형',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 16),
                      vertical: ResponsiveUtils.spacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF8F9FA),
                          const Color(0xFFF2F3F5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 12),
                      ),
                      border: Border.all(
                        color: const Color(0xFFE5E5EA),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedType,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF007AFF),
                          size: ResponsiveUtils.iconSize(context, 24),
                        ),
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1C1C1E),
                        ),
                        items: InquiryService.getInquiryTypes()
                            .map(
                              (type) => DropdownMenuItem(
                                value: type['value'],
                                child: Row(
                                  children: [
                                    Icon(
                                      _getIconForType(type['value']!),
                                      size: ResponsiveUtils.iconSize(context, 18),
                                      color: const Color(0xFF007AFF),
                                    ),
                                    SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                                    Text(type['label']!),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveUtils.spacing(context, 24)),

                  // 내용 입력 섹션
                  Row(
                    children: [
                      Container(
                        width: ResponsiveUtils.spacing(context, 4),
                        height: ResponsiveUtils.spacing(context, 20),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '문의 내용',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 8),
                          vertical: ResponsiveUtils.spacing(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 4),
                          ),
                        ),
                        child: Text(
                          '필수',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF3B30),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 12),
                      ),
                      border: Border.all(
                        color: _messageController.text.isNotEmpty 
                            ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                            : const Color(0xFFE5E5EA),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 8,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        color: const Color(0xFF1C1C1E),
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '문의하실 내용을 자유롭게 작성해주세요.\n\n예시:\n• 앱 사용 중 발생한 오류\n• 기능 개선 제안\n• 사용 방법 문의\n• 기타 불편 사항',
                        hintStyle: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 15,
                          color: const Color(0xFFAEAEB2),
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(
                          ResponsiveUtils.spacing(context, 16),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {}); // 테두리 색상 업데이트를 위해
                      },
                    ),
                  ),

                  // 문자 수 카운터
                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_messageController.text.length} / 1000',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 12,
                        color: _messageController.text.length > 900
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFFAEAEB2),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveUtils.spacing(context, 28)),

                  // 제출 버튼
                  Container(
                    width: double.infinity,
                    height: ResponsiveUtils.spacing(context, 56),
                    decoration: BoxDecoration(
                      gradient: _messageController.text.trim().isEmpty
                          ? null
                          : AppColors.primaryGradient,
                      color: _messageController.text.trim().isEmpty
                          ? const Color(0xFFE5E5EA)
                          : null,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 14),
                      ),
                      boxShadow: _messageController.text.trim().isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                                blurRadius: ResponsiveUtils.spacing(context, 12),
                                offset: Offset(0, ResponsiveUtils.spacing(context, 6)),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (_isSubmitting || _messageController.text.trim().isEmpty) 
                            ? null 
                            : _submitInquiry,
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 14),
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? const CupertinoActivityIndicator(
                                  color: Colors.white,
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      color: _messageController.text.trim().isEmpty
                                          ? const Color(0xFF8E8E93)
                                          : Colors.white,
                                      size: ResponsiveUtils.iconSize(context, 20),
                                    ),
                                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                    Text(
                                      '문의 등록하기',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: _messageController.text.trim().isEmpty
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
                ],
              ),
            ),
          ),
          
          // 도움말 섹션
          SizedBox(height: ResponsiveUtils.spacing(context, 20)),
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.spacing(context, 12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: const Color(0xFF8E8E93),
                  size: ResponsiveUtils.iconSize(context, 20),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '빠른 답변을 위한 팁',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF48484A),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                      Text(
                        '• 문제 발생 시간과 상황을 구체적으로 작성\n• 오류 메시지가 있다면 함께 첨부\n• 업무 시간 내 1~2시간 이내 답변',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 13,
                          color: const Color(0xFF8E8E93),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  /// 문의 목록
  Widget _buildInquiryList() {
    if (_isLoadingInquiries) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_inquiries.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 40)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF007AFF).withValues(alpha: 0.05),
                      const Color(0xFF0051D5).withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  size: ResponsiveUtils.iconSize(context, 48),
                  color: const Color(0xFF007AFF).withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),
              Text(
                _isAdmin ? '아직 문의가 없습니다' : '작성한 문의가 없습니다',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 8)),
              Text(
                _isAdmin 
                    ? '직원들의 문의가 등록되면 여기에 표시됩니다' 
                    : '문의 작성 탭에서 새로운 문의를 등록해보세요',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  color: const Color(0xFF8E8E93),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInquiries,
      color: const Color(0xFF007AFF),
      child: ListView.builder(
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
        itemCount: _inquiries.length,
        itemBuilder: (context, index) {
          final inquiry = _inquiries[index];
          return _buildInquiryCard(inquiry);
        },
      ),
    );
  }

  /// 문의 카드
  Widget _buildInquiryCard(Map<String, dynamic> inquiry) {
    final createdAt = DateTime.parse(inquiry['created_at']);
    final dateStr = DateFormat('MM/dd HH:mm').format(createdAt);
    final status = inquiry['status'] ?? 'open';
    final statusLabel = InquiryService.getStatusLabel(status);
    final statusColor = Color(InquiryService.getStatusColor(status));
    
    // 읽지 않은 답변이 있는지 확인
    final hasUnreadResponse = !_isAdmin && 
        inquiry['resolution_note'] != null && 
        inquiry['resolution_note'].toString().isNotEmpty &&
        (inquiry['is_read'] == false || inquiry['is_read'] == null);

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 16),
        ),
        border: Border.all(
          color: hasUnreadResponse 
              ? const Color(0xFF007AFF).withValues(alpha: 0.3)
              : const Color(0xFFE5E5EA),
          width: hasUnreadResponse ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasUnreadResponse
                ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: ResponsiveUtils.spacing(context, hasUnreadResponse ? 8 : 4),
            offset: Offset(0, ResponsiveUtils.spacing(context, 2)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.spacing(context, 16),
          ),
          onTap: () => _showInquiryDetail(inquiry),
          child: Column(
            children: [
              // 상단 헤더 영역
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 16),
                  vertical: ResponsiveUtils.spacing(context, 12),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.05),
                      statusColor.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                    topRight: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                  ),
                ),
                child: Row(
                  children: [
                    // 문의 유형 아이콘
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 8)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 8),
                        ),
                      ),
                      child: Icon(
                        _getIconForType(inquiry['inquiry_type'] ?? '기타'),
                        size: ResponsiveUtils.iconSize(context, 18),
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                    // 상태 뱃지 (답변 알림 통합)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 10),
                        vertical: ResponsiveUtils.spacing(context, 5),
                      ),
                      decoration: BoxDecoration(
                        color: hasUnreadResponse 
                            ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                            : statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: ResponsiveUtils.spacing(context, 6),
                            height: ResponsiveUtils.spacing(context, 6),
                            decoration: BoxDecoration(
                              color: hasUnreadResponse 
                                  ? const Color(0xFFFF3B30)
                                  : statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                          Text(
                            hasUnreadResponse ? 'NEW 답변' : statusLabel,
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasUnreadResponse 
                                  ? const Color(0xFFFF3B30)
                                  : statusColor,
                            ),
                          ),
                          if (hasUnreadResponse) ...[
                            SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                            Icon(
                              Icons.notification_important_rounded,
                              size: ResponsiveUtils.iconSize(context, 14),
                              color: const Color(0xFFFF3B30),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 날짜
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: ResponsiveUtils.iconSize(context, 14),
                          color: const Color(0xFF8E8E93),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                        Text(
                          dateStr,
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 본문 영역
              Padding(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            inquiry['subject'] ?? '제목 없음',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C1E),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnreadResponse) ...[
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacing(context, 8),
                              vertical: ResponsiveUtils.spacing(context, 3),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 10),
                              ),
                            ),
                            child: Text(
                              'NEW',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // 내용 미리보기
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    Text(
                      inquiry['message'] ?? '',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: const Color(0xFF6E6E73),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 관리자면 작성자 표시
                    if (_isAdmin) ...[
                      SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 10),
                          vertical: ResponsiveUtils.spacing(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: ResponsiveUtils.iconSize(context, 14),
                              color: const Color(0xFF48484A),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                            Text(
                              inquiry['user_name'] ?? '알 수 없음',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF48484A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 답변 알림은 상태 뱃지에 통합됨 (중복 제거)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 문의 상세 보기
  void _showInquiryDetail(Map<String, dynamic> inquiry) async {
    // 일반 사용자가 답변이 있는 문의를 볼 때 읽음 처리
    if (!_isAdmin && inquiry['resolution_note'] != null) {
      await _inquiryService.markInquiryAsRead(inquiry['id']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InquiryDetailSheet(
        inquiry: inquiry,
        isAdmin: _isAdmin,
        onStatusUpdate: (updatedInquiry) {
          // 목록 업데이트
          setState(() {
            final index = _inquiries.indexWhere(
              (i) => i['id'] == updatedInquiry['id'],
            );
            if (index != -1) {
              _inquiries[index] = updatedInquiry;
            }
          });
        },
        onDelete: () {
          // 삭제 후 목록 새로고침
          _loadInquiries();
        },
      ),
    );
  }
}

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
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.inquiry['status'] ?? 'open';
    _resolutionController.text = widget.inquiry['resolution_note'] ?? '';
  }

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  /// 상태 업데이트
  Future<void> _updateStatus() async {
    setState(() {
      _isUpdating = true;
    });

    final result = await _inquiryService.updateInquiryStatus(
      inquiryId: widget.inquiry['id'],
      status: _selectedStatus,
      resolutionNote: _resolutionController.text.trim(),
    );

    setState(() {
      _isUpdating = false;
    });

    if (result['success']) {
      widget.onStatusUpdate(result['data']);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상태가 업데이트되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
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
              Navigator.pop(context); // 다이얼로그 닫기
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
      
      // 목록 새로고침 (부모 화면에서 제공한 콜백 호출)
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

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(widget.inquiry['created_at']);
    final dateStr = DateFormat('yyyy년 MM월 dd일 HH:mm').format(createdAt);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 12)),
            width: ResponsiveUtils.spacing(context, 40),
            height: ResponsiveUtils.spacing(context, 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Padding(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '문의 상세',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 삭제 버튼 (조건부 표시)
                FutureBuilder<Map<String, dynamic>>(
                  future: _inquiryService.canDeleteInquiry(widget.inquiry['id']),
                  builder: (context, snapshot) {
                    final canDelete = snapshot.data?['canDelete'] == true;
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canDelete)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade600,
                            ),
                            onPressed: () => _showDeleteConfirmation(context),
                            tooltip: '문의 삭제',
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 내용
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기본 정보
                  _buildInfoRow('문의 번호', '#${widget.inquiry['id']}'),
                  _buildInfoRow('작성일', dateStr),
                  _buildInfoRow('작성자', widget.inquiry['user_name'] ?? '알 수 없음'),
                  _buildInfoRow('이메일', widget.inquiry['user_email'] ?? '-'),
                  _buildInfoRow(
                    '문의 유형',
                    InquiryService.getInquiryTypeLabel(
                      widget.inquiry['inquiry_type'],
                    ),
                  ),

                  const Divider(height: 32),

                  // 제목
                  Text(
                    '제목',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                  Text(
                    widget.inquiry['subject'] ?? '제목 없음',
                    style: ResponsiveUtils.getTextStyle(context, fontSize: 16),
                  ),

                  SizedBox(height: ResponsiveUtils.spacing(context, 20)),

                  // 내용
                  Text(
                    widget.isAdmin ? '문의 상세' : '문의 내용',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      ResponsiveUtils.spacing(context, 12),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.inquiry['message'] ?? '내용 없음',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // 관리자 답변 섹션
                  if (widget.isAdmin) ...[
                    const Divider(height: 32),
                    Text(
                      '답변',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),

                    // 상태 선택
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 12),
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedStatus,
                          items: const [
                            DropdownMenuItem(value: 'open', child: Text('대기중')),
                            DropdownMenuItem(
                              value: 'in_progress',
                              child: Text('처리중'),
                            ),
                            DropdownMenuItem(
                              value: 'resolved',
                              child: Text('해결됨'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('종료'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                      ),
                    ),

                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),

                    // 답변 입력
                    TextField(
                      controller: _resolutionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '답변을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.all(
                          ResponsiveUtils.spacing(context, 12),
                        ),
                      ),
                    ),
                  ] else if (widget.inquiry['resolution_note'] != null &&
                      widget.inquiry['resolution_note']
                          .toString()
                          .isNotEmpty) ...[
                    // 일반 사용자에게 답변 표시
                    const Divider(height: 32),
                    Text(
                      '관리자 답변',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(
                        ResponsiveUtils.spacing(context, 12),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.inquiry['handled_by'] != null) ...[
                            Text(
                              '담당자: ${widget.inquiry['handled_by']}',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(
                              height: ResponsiveUtils.spacing(context, 8),
                            ),
                          ],
                          Text(
                            widget.inquiry['resolution_note'],
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                ],
              ),
            ),
          ),

          // 하단 버튼 (관리자만)
          if (widget.isAdmin)
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: ResponsiveUtils.spacing(context, 48),
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _updateStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1777CB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isUpdating
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          '상태 업데이트',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveUtils.spacing(context, 100),
            child: Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveUtils.getTextStyle(context, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
