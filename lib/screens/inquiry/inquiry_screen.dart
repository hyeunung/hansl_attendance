import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/inquiry_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'inquiry_detail_sheet.dart';

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
  int _hiddenOldInquiriesCount = 0; // 30일 이전 해결된 문의 수

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

    final allInquiries = await _inquiryService.getInquiries();
    
    // 해결된 문의는 최근 30일치만 필터링
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));
    
    int hiddenCount = 0;
    final inquiries = allInquiries.where((inquiry) {
      final status = inquiry['status'] ?? 'open';
      
      // 대기중(open) 또는 진행중(in_progress)은 모두 표시
      if (status == 'open' || status == 'in_progress') {
        return true;
      }
      
      // 해결됨(resolved)은 최근 30일 이내만 표시
      if (status == 'resolved') {
        final createdAt = DateTime.parse(inquiry['created_at']);
        final isRecent = createdAt.isAfter(oneMonthAgo);
        if (!isRecent) {
          hiddenCount++; // 30일 이전 해결된 문의 카운트
        }
        return isRecent;
      }
      
      return true; // 기타 상태는 모두 표시
    }).toList();
    
    // 정렬 적용
    _sortInquiriesList(inquiries);

    setState(() {
      _inquiries = inquiries;
      _hiddenOldInquiriesCount = hiddenCount;
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
            // 이전 상태 저장 (업데이트 전에!)
            final previousInquiry = Map<String, dynamic>.from(_inquiries[index]);
            
            // 업데이트 적용
            _inquiries[index] = updatedInquiry;
            
            // 업데이트 후 재정렬
            _sortInquiries();

            // app_admin이 아닌 모든 사용자: 문의가 resolved 상태가 되면 알림
            if (!_isAdmin && 
                updatedInquiry['status'] == 'resolved' &&
                previousInquiry['status'] != 'resolved') {
              _showNotification('문의가 완료 처리되었습니다.');
            }
          }
        });
      },
    );
  }

  /// 문의 목록 정렬 (리스트 직접)
  void _sortInquiriesList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      // 먼저 상태로 정렬 (open이 우선)
      final statusA = a['status'] ?? 'open';
      final statusB = b['status'] ?? 'open';
      
      if (statusA == 'open' && statusB != 'open') {
        return -1; // a가 open이면 앞으로
      } else if (statusA != 'open' && statusB == 'open') {
        return 1; // b가 open이면 앞으로
      }
      
      // 같은 상태라면 최신순으로 정렬
      final dateA = DateTime.parse(a['created_at']);
      final dateB = DateTime.parse(b['created_at']);
      return dateB.compareTo(dateA); // 최신이 앞으로
    });
  }

  /// 문의 목록 정렬 (인스턴스 변수)
  void _sortInquiries() {
    _sortInquiriesList(_inquiries);
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
        itemCount: _inquiries.length + (_hiddenOldInquiriesCount > 0 ? 1 : 0), // 숨겨진 문의가 있으면 정보 카드 추가
        itemBuilder: (context, index) {
          // 마지막 아이템이고 숨겨진 문의가 있으면 정보 카드 표시
          if (index == _inquiries.length && _hiddenOldInquiriesCount > 0) {
            return Container(
              margin: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 8)),
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.spacing(context, 12),
                ),
                border: Border.all(
                  color: const Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
              child: Row(
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
                          '30일 이전 해결된 문의',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF48484A),
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                        Text(
                          '$_hiddenOldInquiriesCount건의 문의가 숨겨졌습니다',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 13,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          
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
    final isOpen = status == 'open';  // 대기중 상태 체크
    
    // 채팅형 문의로 전환되면서 답변/읽음은 notifications 기반으로 관리됨
    // 리스트 카드에서 NEW 표시를 쓰고 싶다면, 백엔드에서 has_unread_inquiry_message 같은 필드를 내려주도록 확장 가능
    final hasUnreadResponse =
        !_isAdmin && (inquiry['has_unread_inquiry_message'] == true);

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 16),
        ),
        border: Border.all(
          color: isOpen  // 대기중이면 주황색 테두리
              ? const Color(0xFFFF9500).withValues(alpha: 0.3)
              : hasUnreadResponse 
                  ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                  : const Color(0xFFE5E5EA),
          width: isOpen || hasUnreadResponse ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOpen  // 대기중이면 주황색 그림자
                ? const Color(0xFFFF9500).withValues(alpha: 0.1)
                : hasUnreadResponse
                    ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
            blurRadius: ResponsiveUtils.spacing(context, isOpen || hasUnreadResponse ? 8 : 4),
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
                            : isOpen
                                ? const Color(0xFFFF9500).withValues(alpha: 0.15)  // 대기중이면 주황색
                                : statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOpen && !hasUnreadResponse) ...[  // 대기중이면 시계 아이콘
                            Icon(
                              Icons.schedule_rounded,
                              size: ResponsiveUtils.iconSize(context, 14),
                              color: const Color(0xFFFF9500),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                          ] else ...[
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
                          ],
                          Text(
                            hasUnreadResponse 
                                ? 'NEW 답변' 
                                : isOpen 
                                    ? '답변 대기중'  // 대기중 텍스트 명확하게
                                    : statusLabel,
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasUnreadResponse 
                                  ? const Color(0xFFFF3B30)
                                  : isOpen
                                      ? const Color(0xFFFF9500)  // 대기중이면 주황색
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
    // 일반 사용자는 해당 문의 알림을 읽음 처리 (notifications 기반)
    if (!_isAdmin) {
      await _inquiryService.markInquiryNotificationsAsRead(inquiry['id']);
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
