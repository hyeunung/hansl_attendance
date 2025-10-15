import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_request.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/user_role_helper.dart';

class PurchaseApprovalWidget extends StatefulWidget {
  const PurchaseApprovalWidget({super.key});

  @override
  State<PurchaseApprovalWidget> createState() => _PurchaseApprovalWidgetState();
}

class _PurchaseApprovalWidgetState extends State<PurchaseApprovalWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final NumberFormat currencyFormat = NumberFormat('#,###');
  late TabController _tabController;
  
  // 처리완료 탭 검색 및 필터링을 위한 상태 변수들
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 기본 날짜 설정 (최근 1개월)
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate!.year, _endDate!.month - 1, _endDate!.day);
    
    // 검색 리스너 추가
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    // 탭 변경 리스너 추가
    _tabController.addListener(() {
      // indexIsChanging 조건 제거 - 탭이 완전히 변경된 후에도 처리
      // Debug code removed
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final purchaseProvider = Provider.of<PurchaseProvider>(
        context,
        listen: false,
      );

      // employee가 없으면 아무것도 하지 않음
      if (userProvider.employee == null) {
        // Debug print removed
return;
      }
      
      // Debug code removed

      if (_tabController.index == 1) {
        // Debug print removed
        purchaseProvider.fetchCompletedPurchases(
          employee: userProvider.employee,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else if (_tabController.index == 0) {
        // Debug print removed
        purchaseProvider.fetchPendingPurchases(
          employee: userProvider.employee,
        );
      }
    });

    // 위젯 생성 시 자동으로 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final purchaseProvider = Provider.of<PurchaseProvider>(
        context,
        listen: false,
      );

      // employee가 있을 때만 로드
      if (userProvider.employee != null) {
        // Debug print removed
        purchaseProvider.fetchPendingPurchases(employee: userProvider.employee);
      } else {
        // Debug code removed
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 승인 권한 체크
  bool canApproveMiddle(List<dynamic> roles) {
    return UserRoleHelper.isMiddleManager(roles) || UserRoleHelper.isAppAdmin(roles);
  }

  bool canApproveFinal(List<dynamic> roles, String? paymentCategory) {
    if (UserRoleHelper.isAppAdmin(roles)) return true;
    if (!UserRoleHelper.isFinalApprover(roles)) return false;
    if (paymentCategory == null || paymentCategory.isEmpty) return false;

    // final_approver가 있는 경우 세부 권한 체크
    if (UserRoleHelper.isRawMaterialManager(roles)) {
      return paymentCategory == '발주';
    }
    if (UserRoleHelper.isConsumableManager(roles)) {
      return paymentCategory == '구매 요청';
    }

    return false; // final_approver만 있고 세부 권한 없으면 false
  }

  // 상세보기 다이얼로그
  void _showOrderDetails(BuildContext context, PurchaseOrderGroup group) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.spacing(context, 16),
          ),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            children: [
              // 헤더 (개선된 모던 디자인)
              Container(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveUtils.spacing(context, 24),
                  ResponsiveUtils.spacing(context, 20),
                  ResponsiveUtils.spacing(context, 16),
                  ResponsiveUtils.spacing(context, 20),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                    topRight: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 8)),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: ResponsiveUtils.iconSize(context, 20),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '발주 상세정보',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                          Text(
                            group.purchaseOrderNumber,
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 결제구분 칩 (개선된 디자인)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 12),
                        vertical: ResponsiveUtils.spacing(context, 6),
                      ),
                      decoration: BoxDecoration(
                        color: group.paymentCategory == '발주' 
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 16)),
                        border: Border.all(
                          color: group.paymentCategory == '발주' 
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        group.paymentCategory ?? '',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: ResponsiveUtils.iconSize(context, 24),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: ResponsiveUtils.spacing(context, 20),
                    ),
                  ],
                ),
              ),

              // 상세 내역 (개선된 디자인)
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                  children: [
                    // 기본 정보 카드
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '기본 정보',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                          _buildInfoRow(context, '요청자', group.requesterName),
                          _buildInfoRow(context, '업체명', group.vendorName),
                          _buildInfoRow(
                            context,
                            '요청일',
                            DateFormat('yyyy.MM.dd').format(group.requestDate),
                          ),
                          if (group.items.isNotEmpty &&
                              group.headerItem.deliveryRequestDate != DateTime(1970))
                            _buildInfoRow(
                              context,
                              '입고요청일',
                              DateFormat('yyyy.MM.dd').format(group.headerItem.deliveryRequestDate),
                            ),
                          if (group.headerItem.projectVendor != null &&
                              group.headerItem.projectVendor!.isNotEmpty)
                            _buildInfoRow(
                              context,
                              'PJ업체',
                              group.headerItem.projectVendor!,
                            ),
                          if (group.headerItem.salesOrderNumber != null &&
                              group.headerItem.salesOrderNumber!.isNotEmpty)
                            _buildInfoRow(
                              context,
                              '수주번호',
                              group.headerItem.salesOrderNumber!,
                            ),
                          if (group.headerItem.projectItem != null &&
                              group.headerItem.projectItem!.isNotEmpty)
                            _buildInfoRow(
                              context,
                              'Item',
                              group.headerItem.projectItem!,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 16)),

                    // line_number 순서로 정렬된 아이템들 표시
                    ...(group.items.toList()..sort(
                          (a, b) => a.lineNumber.compareTo(b.lineNumber),
                        ))
                        .map(
                          (item) => Container(
                            margin: EdgeInsets.only(
                              bottom: ResponsiveUtils.spacing(context, 12),
                            ),
                            padding: EdgeInsets.all(
                              ResponsiveUtils.spacing(context, 12),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 10),
                              ),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.lineNumber}. ${item.itemName.isNotEmpty ? item.itemName : "품목명 없음"}',
                                  style: ResponsiveUtils.getTextStyle(
                                    context,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: const Color(0xFF1C1C1E),
                                  ),
                                ),
                                SizedBox(
                                  height: ResponsiveUtils.spacing(context, 8),
                                ),
                                // 규격
                                if (item.specification.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: ResponsiveUtils.spacing(
                                        context,
                                        4,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: ResponsiveUtils.spacing(
                                            context,
                                            60,
                                          ),
                                          child: Text(
                                            '규격:',
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontSize: 13,
                                              color: const Color(0xFF8E8E93),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.specification,
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontSize: 13,
                                              color: const Color(0xFF1C1C1E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // 수량
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: ResponsiveUtils.spacing(context, 4),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: ResponsiveUtils.spacing(
                                          context,
                                          60,
                                        ),
                                        child: Text(
                                          '수량:',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 13,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${item.quantity}',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 13,
                                          color: const Color(0xFF1C1C1E),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 단가
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: ResponsiveUtils.spacing(context, 4),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: ResponsiveUtils.spacing(
                                          context,
                                          60,
                                        ),
                                        child: Text(
                                          '단가:',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 13,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₩${currencyFormat.format(item.unitPriceValue)}',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 13,
                                          color: const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 금액
                                Row(
                                  children: [
                                    SizedBox(
                                      width: ResponsiveUtils.spacing(
                                        context,
                                        60,
                                      ),
                                      child: Text(
                                        '금액:',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 13,
                                          color: const Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '₩${currencyFormat.format(item.amountValue)}',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                // 비고
                                if (item.remark != null &&
                                    item.remark!.isNotEmpty) ...[
                                  SizedBox(
                                    height: ResponsiveUtils.spacing(context, 4),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: ResponsiveUtils.spacing(
                                          context,
                                          60,
                                        ),
                                        child: Text(
                                          '비고:',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 13,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item.remark!,
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 13,
                                            color: const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.spacing(context, 4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: ResponsiveUtils.spacing(context, 80),
            child: Text(
              label,
              style: ResponsiveUtils.getTextStyle(
                context,
                color: const Color(0xFF8E8E93),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ResponsiveUtils.spacing(context, 70),
          child: Text(
            label,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 13,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    return Consumer2<PurchaseProvider, UserProvider>(
      builder: (context, purchaseProvider, userProvider, _) {
        final purchaseRoles =
            userProvider.employee?['purchase_role'] as List<dynamic>? ?? [];

        // 사용자 역할에 따른 대기 개수 계산
        int pendingCount = 0;
        String pendingDetail = '';

        if (UserRoleHelper.isAppAdmin(purchaseRoles)) {
          pendingCount = purchaseProvider.totalPendingCount;
          if (purchaseProvider.middleManagerPendingCount > 0 ||
              purchaseProvider.rawMaterialPendingCount > 0 ||
              purchaseProvider.consumablePendingCount > 0) {
            pendingDetail =
                ' (1차: ${purchaseProvider.middleManagerPendingCount}, '
                '발주: ${purchaseProvider.rawMaterialPendingCount}, '
                '구매: ${purchaseProvider.consumablePendingCount})';
          }
        } else {
          if (UserRoleHelper.isMiddleManager(purchaseRoles)) {
            pendingCount += purchaseProvider.middleManagerPendingCount;
          }
          if (UserRoleHelper.isFinalApprover(purchaseRoles)) {
            if (UserRoleHelper.isRawMaterialManager(purchaseRoles)) {
              pendingCount += purchaseProvider.rawMaterialPendingCount;
            }
            if (UserRoleHelper.isConsumableManager(purchaseRoles)) {
              pendingCount += purchaseProvider.consumablePendingCount;
            }
          }
        }

        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 20),
                vertical: ResponsiveUtils.spacing(context, 12),
              ),
              child: Row(
                children: [
                  // 대기중 칩
                  GestureDetector(
                    onTap: () {
                      _tabController.animateTo(0);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 16),
                        vertical: ResponsiveUtils.spacing(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: _tabController.index == 0
                            ? AppColors.primary
                            : const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '대기중',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _tabController.index == 0
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                            ),
                          ),
                          // 배지 제거됨 (메인 탭에 이미 표시되므로 중복 제거)
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 10)),
                  // 처리완료 칩
                  GestureDetector(
                    onTap: () {
                      _tabController.animateTo(1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 16),
                        vertical: ResponsiveUtils.spacing(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: _tabController.index == 1
                            ? AppColors.primary
                            : const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '처리완료',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _tabController.index == 1
                              ? Colors.white
                              : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                  ),
                  // 처리완료 탭에서만 기간선택 버튼 표시
                  if (_tabController.index == 1) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: _showDateRangePicker,
                      child: Container(
                        constraints: BoxConstraints(minWidth: ResponsiveUtils.spacing(context, 90)),
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 14),
                          vertical: ResponsiveUtils.spacing(context, 8),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 18)),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: ResponsiveUtils.iconSize(context, 16),
                              color: AppColors.primary,
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                            Text(
                              _startDate != null && _endDate != null
                                  ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'
                                  : '한달',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // app_admin인 경우 세부 개수 표시
            if (UserRoleHelper.isAppAdmin(purchaseRoles) &&
                pendingDetail.isNotEmpty &&
                _tabController.index == 0)
              Padding(
                padding: EdgeInsets.only(
                  left: ResponsiveUtils.spacing(context, 20),
                  right: ResponsiveUtils.spacing(context, 20),
                  bottom: ResponsiveUtils.spacing(context, 8),
                ),
                child: Text(
                  pendingDetail,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ),

            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 대기중 탭
                  _buildPendingTab(),
                  // 처리완료 탭
                  _buildCompletedTab(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingTab() {
    return Consumer2<PurchaseProvider, UserProvider>(
      builder: (context, purchaseProvider, userProvider, _) {
        final purchaseRoles =
            userProvider.employee?['purchase_role'] as List<dynamic>? ?? [];

        if (purchaseProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('대기중 데이터를 불러오고 있습니다...'),
              ],
            ),
          );
        }

        if (purchaseProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('오류: ${purchaseProvider.error}'),
                ElevatedButton(
                  onPressed: () => purchaseProvider.fetchPendingPurchases(
                    employee: userProvider.employee,
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        final orders = List<PurchaseOrderGroup>.from(purchaseProvider.pendingOrders)
          ..sort((a, b) {
            // 1차 승인 대기가 우선
            final aIsMiddlePending = a.middleManagerStatus == 'pending';
            final bIsMiddlePending = b.middleManagerStatus == 'pending';
            
            if (aIsMiddlePending && !bIsMiddlePending) return -1;
            if (!aIsMiddlePending && bIsMiddlePending) return 1;
            
            // 같은 승인 단계면 날짜 역순으로 정렬
            return b.requestDate.compareTo(a.requestDate);
          });

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: ResponsiveUtils.iconSize(context, 80),
                  color: const Color(0xFFE0E0E0),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                Text(
                  '승인 대기 중인 발주가 없습니다',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                Text(
                  '새로운 발주 신청이 들어오면 여기에 표시됩니다',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 14,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await purchaseProvider.fetchPendingPurchases(
              employee: userProvider.employee,
            );
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 20),
              vertical: ResponsiveUtils.spacing(context, 20),
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final group = orders[index];
              return _buildPurchaseCard(
                context,
                group,
                purchaseRoles,
                userProvider,
                purchaseProvider,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    return Consumer2<PurchaseProvider, UserProvider>(
      builder: (context, purchaseProvider, userProvider, _) {
        // Debug code removed
        if (purchaseProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('처리완료 데이터를 불러오고 있습니다...'),
              ],
            ),
          );
        }

        if (purchaseProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('오류: ${purchaseProvider.error}'),
                ElevatedButton(
                  onPressed: () => purchaseProvider.fetchCompletedPurchases(
                    employee: userProvider.employee,
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        final orders = purchaseProvider.completedOrders;
        
        // Debug code removed

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_alt,
                  size: ResponsiveUtils.iconSize(context, 80),
                  color: const Color(0xFFE0E0E0),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                Text(
                  '오늘 처리한 발주가 없습니다',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                Text(
                  '오늘 승인하거나 반려한 항목이 여기에 표시됩니다',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 14,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          );
        }

        // 검색어로 필터링된 주문 목록
        final filteredOrders = orders.where((group) {
          if (_searchQuery.isEmpty) return true;
          
          final query = _searchQuery.toLowerCase();
          return group.purchaseOrderNumber.toLowerCase().contains(query) ||
                 group.vendorName.toLowerCase().contains(query) ||
                 group.items.any((item) => 
                   item.itemName.toLowerCase().contains(query) ||
                   item.specification.toLowerCase().contains(query)
                 );
        }).toList();

        return Column(
          children: [
            // 검색창
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 20),
                vertical: ResponsiveUtils.spacing(context, 12),
              ),
              child: SizedBox(
                height: ResponsiveUtils.spacing(context, 36),
                child: TextField(
                  controller: _searchController,
                  style: ResponsiveUtils.getTextStyle(context, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '발주번호, 업체명, 품목명, 규격으로 검색',
                    hintStyle: ResponsiveUtils.getTextStyle(context, 
                      fontSize: 12, 
                      color: const Color(0xFF8E8E93)
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: ResponsiveUtils.iconSize(context, 18),
                      color: const Color(0xFF8E8E93),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: ResponsiveUtils.iconSize(context, 18),
                              color: const Color(0xFF8E8E93),
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 12),
                      vertical: ResponsiveUtils.spacing(context, 6),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            
            // 리스트 뷰
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => purchaseProvider.fetchCompletedPurchases(
                  employee: userProvider.employee,
                  startDate: _startDate,
                  endDate: _endDate,
                ),
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.task_alt,
                              size: ResponsiveUtils.iconSize(context, 80),
                              color: const Color(0xFFE0E0E0),
                            ),
                            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                            Text(
                              _searchQuery.isNotEmpty 
                                  ? '검색 결과가 없습니다'
                                  : '선택한 기간에 처리한 발주가 없습니다',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? '다른 검색어를 시도해보세요'
                                  : '다른 기간을 선택해보세요',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 14,
                                color: const Color(0xFFB0B0B0),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: ResponsiveUtils.spacing(context, 20),
                          right: ResponsiveUtils.spacing(context, 20),
                          bottom: ResponsiveUtils.spacing(context, 20),
                        ),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final group = filteredOrders[index];
                          return _buildCompletedCard(context, group);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPurchaseCard(
    BuildContext context,
    PurchaseOrderGroup group,
    List<dynamic> purchaseRoles,
    UserProvider userProvider,
    PurchaseProvider purchaseProvider,
  ) {
    final headerItem = group.headerItem;

    // payment_category에 따른 색상 설정
    final Color categoryBgColor;
    final Color categoryTextColor;
    if (group.paymentCategory == '발주') {
      categoryBgColor = const Color(0xFFE8F5E9); // 연한 녹색 배경
      categoryTextColor = const Color(0xFF4CAF50); // 녹색 텍스트
    } else {
      categoryBgColor = const Color(0xFFE3F2FD); // 연한 파란색 배경
      categoryTextColor = const Color(0xFF1976D2); // 파란색 텍스트
    }

    // 승인 상태에 따른 색상 설정
    final Color statusBgColor;
    final Color statusTextColor;
    String statusLabel;
    if (group.finalManagerStatus == 'approved') {
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = const Color(0xFF388E3C);
      statusLabel = '최종승인';
    } else if (group.middleManagerStatus == 'approved') {
      statusBgColor = const Color(0xFFFFF3E0);
      statusTextColor = const Color(0xFFFF9800);
      statusLabel = '1차승인';
    } else {
      statusBgColor = const Color(0xFFFFEBEE);
      statusTextColor = const Color(0xFFC62828);
      statusLabel = '대기중';
    }

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 14),
        ),
        boxShadow: AppShadows.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(context, group),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 14),
        ),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 발주번호, 카테고리, 상태
              Row(
                children: [
                  Icon(
                    Icons.receipt,
                    color: AppColors.primary,
                    size: ResponsiveUtils.iconSize(context, 22),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  Expanded(
                    child: Text(
                      group.purchaseOrderNumber,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 10),
                      vertical: ResponsiveUtils.spacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: categoryBgColor,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: Text(
                      group.paymentCategory ?? '',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: categoryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 10),
                      vertical: ResponsiveUtils.spacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: statusTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveUtils.spacing(context, 16)),

              // 요청자 & 업체 정보
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: ResponsiveUtils.iconSize(context, 16),
                    color: const Color(0xFF8E8E93),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    group.requesterName,
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                  Icon(
                    Icons.business,
                    size: ResponsiveUtils.iconSize(context, 16),
                    color: const Color(0xFF8E8E93),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Expanded(
                    child: Text(
                      group.vendorName,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: const Color(0xFF1C1C1E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveUtils.spacing(context, 12)),

              // 품목 정보
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 10)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 품명
                    Text(
                      headerItem.itemName.isNotEmpty
                          ? headerItem.itemName
                          : '품목명 없음',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                    // 규격과 수량을 한 줄에 표시
                    Row(
                      children: [
                        if (headerItem.specification.isNotEmpty) ...[
                          Expanded(
                            child: Text(
                              '규격: ${headerItem.specification}',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 12,
                                color: const Color(0xFF8E8E93),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                        ],
                        Text(
                          '수량: ${headerItem.quantity}',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: const Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // 추가 품목 표시
                    if (group.additionalItemCount > 0) ...[
                      SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 8),
                          vertical: ResponsiveUtils.spacing(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.051),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 4),
                          ),
                        ),
                        child: Text(
                          '외 ${group.additionalItemCount}개 품목',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: ResponsiveUtils.spacing(context, 16)),

              // 하단: 금액 & 승인 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '총 금액',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 12,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      Text(
                        '₩${currencyFormat.format(group.totalAmount)}',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 1차 승인 버튼
                      if (canApproveMiddle(purchaseRoles) &&
                          group.middleManagerStatus == 'pending')
                        ElevatedButton(
                          onPressed: () async {
                            // 승인 확인 다이얼로그
                            final confirmed = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.spacing(context, 20),
                                  ),
                                ),
                                child: Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.85,
                                  padding: EdgeInsets.all(
                                    ResponsiveUtils.spacing(context, 24),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 아이콘
                                      Container(
                                        width: ResponsiveUtils.spacing(
                                          context,
                                          60,
                                        ),
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          60,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF4CAF50,
                                          ).withValues(alpha: 0.102),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check_circle_outline,
                                          color: const Color(0xFF4CAF50),
                                          size: ResponsiveUtils.iconSize(
                                            context,
                                            32,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          20,
                                        ),
                                      ),

                                      // 제목
                                      Text(
                                        '1차 승인',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          8,
                                        ),
                                      ),

                                      // 설명
                                      Text(
                                        '발주를 승인하시겠습니까?',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 14,
                                          color: const Color(0xFF8E8E93),
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          20,
                                        ),
                                      ),

                                      // 정보 카드
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(
                                          ResponsiveUtils.spacing(context, 16),
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(
                                            ResponsiveUtils.spacing(
                                              context,
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildDialogInfoRow(
                                              context,
                                              '발주번호',
                                              group.purchaseOrderNumber,
                                            ),
                                            SizedBox(
                                              height: ResponsiveUtils.spacing(
                                                context,
                                                8,
                                              ),
                                            ),
                                            _buildDialogInfoRow(
                                              context,
                                              '요청자',
                                              group.requesterName,
                                            ),
                                            SizedBox(
                                              height: ResponsiveUtils.spacing(
                                                context,
                                                8,
                                              ),
                                            ),
                                            _buildDialogInfoRow(
                                              context,
                                              '업체',
                                              group.vendorName,
                                            ),
                                            SizedBox(
                                              height: ResponsiveUtils.spacing(
                                                context,
                                                8,
                                              ),
                                            ),
                                            _buildDialogInfoRow(
                                              context,
                                              '총 금액',
                                              '₩${currencyFormat.format(group.totalAmount)}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          24,
                                        ),
                                      ),

                                      // 버튼
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.symmetric(
                                                  vertical:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        14,
                                                      ),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        ResponsiveUtils.spacing(
                                                          context,
                                                          12,
                                                        ),
                                                      ),
                                                  side: const BorderSide(
                                                    color: Color(0xFFE0E0E0),
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                '취소',
                                                style:
                                                    ResponsiveUtils.getTextStyle(
                                                      context,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                        0xFF8E8E93,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: ResponsiveUtils.spacing(
                                              context,
                                              12,
                                            ),
                                          ),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF4CAF50,
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  vertical:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        14,
                                                      ),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        ResponsiveUtils.spacing(
                                                          context,
                                                          12,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              child: Text(
                                                '승인',
                                                style:
                                                    ResponsiveUtils.getTextStyle(
                                                      context,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                            );

                            if (confirmed == true && context.mounted) {
                              // BuildContext 저장
                              final scaffoldContext = context;
                              
                              // 로딩 다이얼로그 표시
                              showDialog(
                                context: scaffoldContext,
                                barrierDismissible: false,
                                builder: (dialogContext) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              
                              final success = await purchaseProvider
                                  .approveMiddle(group.purchaseOrderNumber);
                              
                              // 로딩 다이얼로그 닫기
                              if (scaffoldContext.mounted) {
                                Navigator.of(scaffoldContext).pop();
                              }
                              
                              if (scaffoldContext.mounted) {
                                if (success) {
                                  // 성공 모달 표시
                                  showDialog(
                                    context: scaffoldContext,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              child: const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 40,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              '1차 승인 완료',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '발주번호: ${group.purchaseOrderNumber}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(dialogContext).pop();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 32,
                                                  vertical: 12,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                '확인',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  
                                  // 실시간 데이터 업데이트
                                  await purchaseProvider.fetchPendingPurchases(
                                    employee: userProvider.employee,
                                  );
                                } else {
                                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                    SnackBar(
                                      content: Text('1차 승인 실패: ${purchaseProvider.error ?? "알 수 없는 오류"}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 8),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacing(context, 16),
                              vertical: ResponsiveUtils.spacing(context, 8),
                            ),
                          ),
                          child: Text(
                            '1차 승인',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      if (canApproveMiddle(purchaseRoles) &&
                          group.middleManagerStatus == 'pending')
                        SizedBox(width: ResponsiveUtils.spacing(context, 8)),

                      // 최종 승인 버튼
                      if (canApproveFinal(
                            purchaseRoles,
                            group.paymentCategory,
                          ) &&
                          group.middleManagerStatus == 'approved' &&
                          group.finalManagerStatus == 'pending')
                        ElevatedButton(
                          onPressed: () async {
                            // 승인 확인 다이얼로그
                            final confirmed = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.spacing(context, 20),
                                  ),
                                ),
                                child: Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.85,
                                  padding: EdgeInsets.all(
                                    ResponsiveUtils.spacing(context, 24),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 아이콘
                                      Container(
                                        width: ResponsiveUtils.spacing(
                                          context,
                                          60,
                                        ),
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          60,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.primary.withValues(
                                                alpha: 0.153,
                                              ),
                                              AppColors.primary.withValues(
                                                alpha: 0.051,
                                              ),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.verified_outlined,
                                          color: AppColors.primary,
                                          size: ResponsiveUtils.iconSize(
                                            context,
                                            32,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          20,
                                        ),
                                      ),

                                      // 제목
                                      Text(
                                        '최종 승인',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          8,
                                        ),
                                      ),

                                      // 설명
                                      Text(
                                        '발주를 최종 승인하시겠습니까?',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 14,
                                          color: const Color(0xFF8E8E93),
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          20,
                                        ),
                                      ),

                                      // 정보 카드
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(
                                          ResponsiveUtils.spacing(context, 16),
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(
                                            ResponsiveUtils.spacing(
                                              context,
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildDialogInfoRow(
                                              context,
                                              '발주번호',
                                              group.purchaseOrderNumber,
                                            ),
                                            SizedBox(
                                              height: ResponsiveUtils.spacing(
                                                context,
                                                8,
                                              ),
                                            ),
                                            _buildDialogInfoRow(
                                              context,
                                              '요청자',
                                              group.requesterName,
                                            ),
                                            SizedBox(
                                              height: ResponsiveUtils.spacing(
                                                context,
                                                8,
                                              ),
                                            ),
                                            _buildDialogInfoRow(
                                              context,
                                              '업체',
                                              group.vendorName,
                                            ),
                                            SizedBox(
                                              height: ResponsiveUtils.spacing(
                                                context,
                                                8,
                                              ),
                                            ),
                                            _buildDialogInfoRow(
                                              context,
                                              '총 금액',
                                              '₩${currencyFormat.format(group.totalAmount)}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: ResponsiveUtils.spacing(
                                          context,
                                          24,
                                        ),
                                      ),

                                      // 버튼
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.symmetric(
                                                  vertical:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        14,
                                                      ),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        ResponsiveUtils.spacing(
                                                          context,
                                                          12,
                                                        ),
                                                      ),
                                                  side: const BorderSide(
                                                    color: Color(0xFFE0E0E0),
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                '취소',
                                                style:
                                                    ResponsiveUtils.getTextStyle(
                                                      context,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                        0xFF8E8E93,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: ResponsiveUtils.spacing(
                                              context,
                                              12,
                                            ),
                                          ),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primary,
                                                padding: EdgeInsets.symmetric(
                                                  vertical:
                                                      ResponsiveUtils.spacing(
                                                        context,
                                                        14,
                                                      ),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        ResponsiveUtils.spacing(
                                                          context,
                                                          12,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              child: Text(
                                                '최종 승인',
                                                style:
                                                    ResponsiveUtils.getTextStyle(
                                                      context,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                            );

                            if (confirmed == true && context.mounted) {
                              // BuildContext 저장
                              final scaffoldContext = context;
                              
                              // 로딩 다이얼로그 표시
                              showDialog(
                                context: scaffoldContext,
                                barrierDismissible: false,
                                builder: (dialogContext) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              
                              final success = await purchaseProvider
                                  .approveFinal(group.purchaseOrderNumber);
                              
                              // 로딩 다이얼로그 닫기
                              if (scaffoldContext.mounted) {
                                Navigator.of(scaffoldContext).pop();
                              }
                              
                              if (scaffoldContext.mounted) {
                                if (success) {
                                  // 성공 모달 표시
                                  showDialog(
                                    context: scaffoldContext,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              child: Icon(
                                                Icons.check_circle,
                                                color: AppColors.primary,
                                                size: 40,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              '최종 승인 완료',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '발주번호: ${group.purchaseOrderNumber}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(dialogContext).pop();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 32,
                                                  vertical: 12,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                '확인',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  
                                  // 실시간 데이터 업데이트
                                  await purchaseProvider.fetchPendingPurchases(
                                    employee: userProvider.employee,
                                  );
                                } else {
                                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                    SnackBar(
                                      content: Text('최종 승인 실패: ${purchaseProvider.error ?? "알 수 없는 오류"}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 8),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacing(context, 16),
                              vertical: ResponsiveUtils.spacing(context, 8),
                            ),
                          ),
                          child: Text(
                            '최종 승인',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // 반려 버튼
                      if ((canApproveMiddle(purchaseRoles) &&
                              group.middleManagerStatus == 'pending') ||
                          (canApproveFinal(
                                purchaseRoles,
                                group.paymentCategory,
                              ) &&
                              group.middleManagerStatus == 'approved' &&
                              group.finalManagerStatus == 'pending')) ...[
                        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                        OutlinedButton(
                          onPressed: () {
                            // 반려 사유 입력 다이얼로그
                            _showRejectDialog(
                              context,
                              group,
                              purchaseRoles,
                              userProvider,
                              purchaseProvider,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF3B30)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 8),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacing(context, 16),
                              vertical: ResponsiveUtils.spacing(context, 8),
                            ),
                          ),
                          child: Text(
                            '반려',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              color: const Color(0xFFFF3B30),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context, PurchaseOrderGroup group) {
    final headerItem = group.headerItem;

    // payment_category에 따른 색상 설정
    final Color categoryBgColor;
    final Color categoryTextColor;
    if (group.paymentCategory == '발주') {
      categoryBgColor = const Color(0xFFE8F5E9);
      categoryTextColor = const Color(0xFF4CAF50);
    } else {
      categoryBgColor = const Color(0xFFE3F2FD);
      categoryTextColor = const Color(0xFF1976D2);
    }

    // 승인 상태에 따른 색상 설정
    final Color statusBgColor;
    final Color statusTextColor;
    String statusLabel;

    if (group.finalManagerStatus == 'approved') {
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = const Color(0xFF388E3C);
      statusLabel = '최종승인';
    } else if (group.finalManagerStatus == 'rejected') {
      statusBgColor = const Color(0xFFFFEBEE);
      statusTextColor = const Color(0xFFC62828);
      statusLabel = '최종반려';
    } else if (group.middleManagerStatus == 'approved') {
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = const Color(0xFF388E3C);
      statusLabel = '1차승인';
    } else if (group.middleManagerStatus == 'rejected') {
      statusBgColor = const Color(0xFFFFEBEE);
      statusTextColor = const Color(0xFFC62828);
      statusLabel = '1차반려';
    } else {
      statusBgColor = const Color(0xFFF2F3F5);
      statusTextColor = const Color(0xFF8E8E93);
      statusLabel = '처리완료';
    }

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 14),
        ),
        boxShadow: AppShadows.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(context, group),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.spacing(context, 14),
        ),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 발주번호, 카테고리, 상태
              Row(
                children: [
                  Icon(
                    Icons.task_alt,
                    color: const Color(0xFF8E8E93),
                    size: ResponsiveUtils.iconSize(context, 22),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  Expanded(
                    child: Text(
                      group.purchaseOrderNumber,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 10),
                      vertical: ResponsiveUtils.spacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: categoryBgColor,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: Text(
                      group.paymentCategory ?? '',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: categoryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacing(context, 10),
                      vertical: ResponsiveUtils.spacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.spacing(context, 8),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: statusTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveUtils.spacing(context, 16)),

              // 요청자 & 업체 정보
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: ResponsiveUtils.iconSize(context, 16),
                    color: const Color(0xFF8E8E93),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    group.requesterName,
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                  Icon(
                    Icons.business,
                    size: ResponsiveUtils.iconSize(context, 16),
                    color: const Color(0xFF8E8E93),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Expanded(
                    child: Text(
                      group.vendorName,
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 14,
                        color: const Color(0xFF1C1C1E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveUtils.spacing(context, 12)),

              // 품목 정보
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 10)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerItem.itemName.isNotEmpty
                          ? headerItem.itemName
                          : '품목명 없음',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (group.additionalItemCount > 0) ...[
                      SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 8),
                          vertical: ResponsiveUtils.spacing(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.051),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 4),
                          ),
                        ),
                        child: Text(
                          '외 ${group.additionalItemCount}개 품목',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: ResponsiveUtils.spacing(context, 16)),

              // 하단: 금액
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '총 금액',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 12,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      Text(
                        '₩${currencyFormat.format(group.totalAmount)}',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '오늘 처리됨',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 12,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    PurchaseOrderGroup group,
    List<dynamic> purchaseRoles,
    UserProvider userProvider,
    PurchaseProvider purchaseProvider,
  ) {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.spacing(context, 20),
          ),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘
              Container(
                width: ResponsiveUtils.spacing(context, 60),
                height: ResponsiveUtils.spacing(context, 60),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.102),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block_outlined,
                  color: const Color(0xFFFF3B30),
                  size: ResponsiveUtils.iconSize(context, 32),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),

              // 제목
              Text(
                '반려 확인',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 8)),

              // 설명
              Text(
                '이 발주를 반려하시겠습니까?',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),

              // 정보 카드
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.spacing(context, 12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogInfoRow(
                      context,
                      '발주번호',
                      group.purchaseOrderNumber,
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    _buildDialogInfoRow(context, '요청자', group.requesterName),
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    _buildDialogInfoRow(context, '업체', group.vendorName),
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    _buildDialogInfoRow(
                      context,
                      '금액',
                      '${group.totalAmount.toStringAsFixed(0)}원',
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 24)),

              // 버튼
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 12),
                          ),
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // BuildContext 저장
                        final dialogContext = context;
                        final scaffoldContext = context;
                        
                        final isMiddleManager =
                            canApproveMiddle(purchaseRoles) &&
                            group.middleManagerStatus == 'pending';

                        final success = await purchaseProvider.rejectPurchase(
                          group.purchaseOrderNumber,
                          isMiddleManager: isMiddleManager,
                          reason: '확인 후 반려',
                        );

                        if (success && dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          if (scaffoldContext.mounted) {
                            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                              const SnackBar(content: Text('반려 처리되었습니다')),
                            );
                            await purchaseProvider.fetchPendingPurchases(
                              employee: userProvider.employee,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.spacing(context, 14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.spacing(context, 12),
                          ),
                        ),
                      ),
                      child: Text(
                        '반려',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
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
    );
  }
  
  // 기간 선택 다이얼로그
  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });

      // 새로운 기간으로 데이터 다시 로드
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      if (userProvider.employee != null) {
        await purchaseProvider.fetchCompletedPurchases(
          employee: userProvider.employee,
          startDate: _startDate,
          endDate: _endDate,
        );
      }
    }
  }
}
