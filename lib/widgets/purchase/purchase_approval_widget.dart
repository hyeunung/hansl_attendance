import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/purchase_request.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';
import '../../utils/user_role_helper.dart';
import '../../widgets/common/notification_banner_widget.dart';

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
                            style: AppTextStyles.tableHeader(context).copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                          Text(
                            group.purchaseOrderNumber,
                            style: AppTextStyles.cardTitle(context).copyWith(
                              color: Colors.white,
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
                            ? AppColors.success.withValues(alpha: 0.2)
                            : AppColors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                        border: Border.all(
                          color: group.paymentCategory == '발주' 
                              ? AppColors.success.withValues(alpha: 0.5)
                              : AppColors.purple.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        group.paymentCategory ?? '',
                        style: AppTextStyles.chipSmall(context, color: Colors.white),
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
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '기본 정보',
                            style: AppTextStyles.sectionSubtitle(context),
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
                                color: AppColors.border,
                              ),
                              boxShadow: AppShadows.xsShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.lineNumber}. ${item.itemName.isNotEmpty ? item.itemName : "품목명 없음"}',
                                  style: AppTextStyles.inputLabel(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
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
                                            style: AppTextStyles.cardCaption(context),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.specification,
                                            style: AppTextStyles.cardCaption(context).copyWith(
                                              color: AppColors.textPrimary,
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
                                          style: AppTextStyles.cardCaption(context),
                                        ),
                                      ),
                                      Text(
                                        '${item.quantity}',
                                        style: AppTextStyles.cardCaption(context).copyWith(
                                          color: AppColors.textPrimary,
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
                                          style: AppTextStyles.cardCaption(context),
                                        ),
                                      ),
                                      Text(
                                        '₩${currencyFormat.format(item.unitPriceValue)}',
                                        style: AppTextStyles.cardCaption(context).copyWith(
                                          color: AppColors.textPrimary,
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
                                        style: AppTextStyles.cardCaption(context),
                                      ),
                                    ),
                                    Text(
                                      '₩${currencyFormat.format(item.amountValue)}',
                                      style: AppTextStyles.inputLabel(context).copyWith(
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
                                          style: AppTextStyles.cardCaption(context),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item.remark!,
                                          style: AppTextStyles.cardCaption(context).copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                // 수정/삭제 버튼 (관리자만 표시)
                                if (_isAppAdmin()) ...[
                                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // 수정 버튼
                                      SizedBox(
                                        width: ResponsiveUtils.spacing(context, 32),
                                        height: ResponsiveUtils.spacing(context, 32),
                                        child: IconButton(
                                          onPressed: () => _showEditDialog(item),
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: ResponsiveUtils.iconSize(context, 16),
                                            color: AppColors.success,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppColors.successLight,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                ResponsiveUtils.spacing(context, 8),
                                              ),
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          tooltip: '품목 수정',
                                        ),
                                      ),
                                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                      // 삭제 버튼
                                      SizedBox(
                                        width: ResponsiveUtils.spacing(context, 32),
                                        height: ResponsiveUtils.spacing(context, 32),
                                        child: IconButton(
                                          onPressed: () => _showDeleteDialog(item, group.purchaseOrderNumber),
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: ResponsiveUtils.iconSize(context, 16),
                                            color: AppColors.error,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppColors.errorLight,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                ResponsiveUtils.spacing(context, 8),
                                              ),
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          tooltip: '품목 삭제',
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
              style: AppTextStyles.tableCellSub(context).copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.tableCellSub(context).copyWith(
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
            style: AppTextStyles.listSubtitle(context),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.listSubtitle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
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
        // 사용자 역할에 따른 대기 개수 계산 (현재 사용되지 않음)

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
                            : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '대기중',
                            style: AppTextStyles.inputLabel(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: _tabController.index == 0
                                  ? Colors.white
                                  : AppColors.textPrimary,
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
                            : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '처리완료',
                        style: AppTextStyles.inputLabel(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: _tabController.index == 1
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // 처리완료 탭에서만 기간선택 버튼 표시
                  if (_tabController.index == 1) ...[
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 기간선택 버튼
                        GestureDetector(
                          onTap: _showDateRangePicker,
                          child: Container(
                            constraints: BoxConstraints(minWidth: ResponsiveUtils.spacing(context, 90)),
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacing(context, 14),
                              vertical: ResponsiveUtils.spacing(context, 8),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 18)),
                              border: Border.all(color: AppColors.border),
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
                                  style: AppTextStyles.chipLabel(context, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                        // 초기화 버튼
                        GestureDetector(
                          onTap: _resetDateRange,
                          child: Container(
                            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 8)),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 18)),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.refresh,
                              size: ResponsiveUtils.iconSize(context, 16),
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 관리자인 경우 세부 개수 표시 (현재 사용되지 않음)

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
        final purchaseRoles = UserRoleHelper.getRoles(userProvider.employee);

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
          return RefreshIndicator(
            onRefresh: () async {
              await purchaseProvider.fetchPendingPurchases(
                employee: userProvider.employee,
              );
              if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 20),
                vertical: ResponsiveUtils.spacing(context, 20),
              ),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: ResponsiveUtils.iconSize(context, 80),
                        color: AppColors.border,
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                      Text(
                        '승인 대기 중인 발주가 없습니다',
                        style: AppTextStyles.cardTitle(context).copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '새로운 발주 신청이 들어오면 여기에 표시됩니다',
                        style: AppTextStyles.emptyState(context).copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
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
            if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
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
          return RefreshIndicator(
            onRefresh: () async {
              await purchaseProvider.fetchCompletedPurchases(
                employee: userProvider.employee,
                startDate: _startDate,
                endDate: _endDate,
              );
              if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 20),
                vertical: ResponsiveUtils.spacing(context, 20),
              ),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: ResponsiveUtils.iconSize(context, 80),
                        color: AppColors.border,
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                      Text(
                        '오늘 처리한 발주가 없습니다',
                        style: AppTextStyles.cardTitle(context).copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '오늘 승인하거나 반려한 항목이 여기에 표시됩니다',
                        style: AppTextStyles.emptyState(context).copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
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
                  style: AppTextStyles.cardCaption(context).copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '발주번호, 업체명, 품목명, 규격으로 검색',
                    hintStyle: AppTextStyles.tableHeader(context),
                    prefixIcon: Icon(
                      Icons.search,
                      size: ResponsiveUtils.iconSize(context, 18),
                      color: AppColors.textTertiary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: ResponsiveUtils.iconSize(context, 18),
                              color: AppColors.textTertiary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                      borderSide: const BorderSide(color: AppColors.border),
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
                onRefresh: () async {
                  await purchaseProvider.fetchCompletedPurchases(
                    employee: userProvider.employee,
                    startDate: _startDate,
                    endDate: _endDate,
                  );
                  if (mounted) AppBanner.show(context, '새로고침 완료', type: BannerType.success);
                },
                child: filteredOrders.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacing(context, 20),
                          vertical: ResponsiveUtils.spacing(context, 20),
                        ),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  _searchQuery.isNotEmpty ? Icons.search_off : Icons.task_alt,
                                  size: ResponsiveUtils.iconSize(context, 80),
                                  color: AppColors.border,
                                ),
                                SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                                Text(
                                  _searchQuery.isNotEmpty 
                                      ? '검색 결과가 없습니다'
                                      : '선택한 기간에 처리한 발주가 없습니다',
                                  style: AppTextStyles.cardTitle(context).copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? '다른 검색어를 시도해보세요'
                                      : '다른 기간을 선택해보세요',
                                  style: AppTextStyles.emptyState(context).copyWith(
                                    color: AppColors.textDisabled,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
    final Color categoryTextColor;
    if (group.paymentCategory == '발주') {
      categoryTextColor = AppColors.success;
    } else {
      categoryTextColor = AppColors.biztrip;
    }

    // 승인 상태에 따른 색상 설정
    final Color statusTextColor;
    String statusLabel;
    if (group.finalManagerStatus == 'approved') {
      statusTextColor = AppColors.success;
      statusLabel = '최종승인';
    } else if (group.middleManagerStatus == 'approved') {
      statusTextColor = AppColors.warning;
      statusLabel = '1차승인';
    } else {
      statusTextColor = AppColors.error;
      statusLabel = '대기중';
    }

    // 선진행 여부에 따른 카드 배경색 설정
    final bool isPreProgress = group.progressType == '선진행';
    final Color cardBackgroundColor = isPreProgress 
        ? AppColors.errorLight  // 연붉은색
        : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: cardBackgroundColor,  // 선진행이면 연붉은색
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
          left: isPreProgress ? BorderSide(color: AppColors.error, width: 3) : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(context, group),
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
                        style: AppTextStyles.sectionSubtitle(context),
                      ),
                    ),
                    StatusChip(
                      label: group.paymentCategory ?? '',
                      color: categoryTextColor,
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    StatusChip(
                      label: statusLabel,
                      color: statusTextColor,
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
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    group.requesterName,
                    style: AppTextStyles.tableCellSub(context),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                  Icon(
                    Icons.business,
                    size: ResponsiveUtils.iconSize(context, 16),
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Expanded(
                    child: Text(
                      group.vendorName,
                      style: AppTextStyles.tableCellSub(context),
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
                  color: AppColors.backgroundSecondary,
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
                      style: AppTextStyles.listTitle(context),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                    // 규격과 수량을 한 줄에 표시
                    Row(
                      children: [
                        if (headerItem.specification.isNotEmpty) ...[
                          Expanded(
                            child: Text(
                              '규격: ${headerItem.specification}',
                              style: AppTextStyles.tableHeader(context),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                        ],
                        Text(
                          '수량: ${headerItem.quantity}',
                          style: AppTextStyles.tableHeader(context).copyWith(
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
                          style: AppTextStyles.tableHeader(context).copyWith(
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
                        style: AppTextStyles.tableHeader(context),
                      ),
                      Text(
                        '₩${currencyFormat.format(group.totalAmount)}',
                        style: AppTextStyles.cardTitle(context).copyWith(
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
                                          color: AppColors.success.withValues(alpha: 0.102),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check_circle_outline,
                                          color: AppColors.success,
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
                                        style: AppTextStyles.sectionTitle(context),
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
                                        style: AppTextStyles.emptyState(context),
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
                                          color: AppColors.backgroundSecondary,
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
                                                    color: AppColors.border,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                '취소',
                                                style:
                                                    AppTextStyles.sectionSubtitle(context).copyWith(
                                                      color: AppColors.textTertiary,
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
                                                backgroundColor: AppColors.success,
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
                                                    AppTextStyles.sectionSubtitle(context).copyWith(
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
                              BuildContext? loadingContext;
                              
                              // 로딩 다이얼로그 표시
                              showDialog(
                                context: scaffoldContext,
                                barrierDismissible: false,
                                builder: (dialogContext) {
                                  loadingContext = dialogContext;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              );
                              
                              bool success = false;
                              try {
                                success = await purchaseProvider
                                    .approveMiddle(group.purchaseOrderNumber);
                              } finally {
                                // 로딩 다이얼로그 닫기
                                if (loadingContext != null && loadingContext!.mounted) {
                                  Navigator.of(loadingContext!).pop();
                                }
                              }
                              
                              if (scaffoldContext.mounted) {
                                if (success) {
                                  // 성공 모달 표시
                                  showDialog(
                                    context: scaffoldContext,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                                                color: AppColors.success.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              child: const Icon(
                                                Icons.check_circle,
                                                color: AppColors.success,
                                                size: 40,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              '1차 승인 완료',
                                              style: AppTextStyles.cardTitle(context),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '발주번호: ${group.purchaseOrderNumber}',
                                              style: AppTextStyles.emptyState(context).copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(dialogContext).pop();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.success,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 32,
                                                  vertical: 12,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                '확인',
                                                style: AppTextStyles.sectionSubtitle(context).copyWith(
                                                  color: Colors.white,
                                                ),
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
                                  AppBanner.show(scaffoldContext, '1차 승인 실패: ${purchaseProvider.error ?? "알 수 없는 오류"}', type: BannerType.error);
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
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
                            style: AppTextStyles.inputLabel(context).copyWith(
                              color: Colors.white,
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
                                        style: AppTextStyles.sectionTitle(context),
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
                                        style: AppTextStyles.emptyState(context),
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
                                          color: AppColors.backgroundSecondary,
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
                                                    color: AppColors.border,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                '취소',
                                                style:
                                                    AppTextStyles.sectionSubtitle(context).copyWith(
                                                      color: AppColors.textTertiary,
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
                                                    AppTextStyles.sectionSubtitle(context).copyWith(
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
                              BuildContext? loadingContext;
                              
                              // 로딩 다이얼로그 표시
                              showDialog(
                                context: scaffoldContext,
                                barrierDismissible: false,
                                builder: (dialogContext) {
                                  loadingContext = dialogContext;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              );
                              
                              bool success = false;
                              try {
                                success = await purchaseProvider
                                    .approveFinal(group.purchaseOrderNumber);
                              } finally {
                                // 로딩 다이얼로그 닫기
                                if (loadingContext != null && loadingContext!.mounted) {
                                  Navigator.of(loadingContext!).pop();
                                }
                              }
                              
                              if (scaffoldContext.mounted) {
                                if (success) {
                                  // 성공 모달 표시
                                  showDialog(
                                    context: scaffoldContext,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                                            Text(
                                              '최종 승인 완료',
                                              style: AppTextStyles.cardTitle(context),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '발주번호: ${group.purchaseOrderNumber}',
                                              style: AppTextStyles.emptyState(context).copyWith(
                                                color: AppColors.textSecondary,
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
                                              child: Text(
                                                '확인',
                                                style: AppTextStyles.sectionSubtitle(context).copyWith(
                                                  color: Colors.white,
                                                ),
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
                                  AppBanner.show(scaffoldContext, '최종 승인 실패: ${purchaseProvider.error ?? "알 수 없는 오류"}', type: BannerType.error);
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
                            style: AppTextStyles.inputLabel(context).copyWith(
                              color: Colors.white,
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
                            side: BorderSide(color: AppColors.error),
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
                            style: AppTextStyles.inputLabel(context).copyWith(
                              color: AppColors.error,
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
    final Color categoryTextColor;
    if (group.paymentCategory == '발주') {
      categoryTextColor = AppColors.success;
    } else {
      categoryTextColor = AppColors.biztrip;
    }

    // 승인 상태에 따른 색상 설정
    final Color statusTextColor;
    String statusLabel;

    if (group.finalManagerStatus == 'approved') {
      statusTextColor = AppColors.success;
      statusLabel = '최종승인';
    } else if (group.finalManagerStatus == 'rejected') {
      statusTextColor = AppColors.error;
      statusLabel = '최종반려';
    } else if (group.middleManagerStatus == 'approved') {
      statusTextColor = AppColors.success;
      statusLabel = '1차승인';
    } else if (group.middleManagerStatus == 'rejected') {
      statusTextColor = AppColors.error;
      statusLabel = '1차반려';
    } else {
      statusTextColor = AppColors.textTertiary;
      statusLabel = '처리완료';
    }

    // 선진행 여부에 따른 카드 배경색 설정
    final bool isPreProgress = group.progressType == '선진행';
    final Color cardBackgroundColor = isPreProgress 
        ? AppColors.errorLight  // 연붉은색
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
          left: isPreProgress ? BorderSide(color: AppColors.error, width: 3) : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(context, group),
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
                    color: AppColors.textTertiary,
                    size: ResponsiveUtils.iconSize(context, 22),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  Expanded(
                    child: Text(
                      group.purchaseOrderNumber,
                      style: AppTextStyles.sectionSubtitle(context),
                    ),
                  ),
                  StatusChip(
                    label: group.paymentCategory ?? '',
                    color: categoryTextColor,
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                  StatusChip(
                    label: statusLabel,
                    color: statusTextColor,
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
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    group.requesterName,
                    style: AppTextStyles.tableCellSub(context),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                  Icon(
                    Icons.business,
                    size: ResponsiveUtils.iconSize(context, 16),
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                  Expanded(
                    child: Text(
                      group.vendorName,
                      style: AppTextStyles.tableCellSub(context),
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
                  color: AppColors.backgroundSecondary,
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
                      style: AppTextStyles.inputLabel(context).copyWith(
                        fontWeight: FontWeight.w600,
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
                          style: AppTextStyles.tableHeader(context).copyWith(
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

              // 하단: 금액과 전체삭제 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '총 금액',
                        style: AppTextStyles.tableHeader(context),
                      ),
                      Text(
                        '₩${currencyFormat.format(group.totalAmount)}',
                        style: AppTextStyles.cardTitle(context).copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 관리자만 전체삭제 버튼 표시
                      if (_isAppAdmin()) ...[
                        GestureDetector(
                          onTap: () => _showBulkDeleteOrderDialog(group),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacing(context, 8),
                              vertical: ResponsiveUtils.spacing(context, 6),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 6)),
                              border: Border.all(
                                color: AppColors.errorLight,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_sweep_outlined,
                                  size: ResponsiveUtils.iconSize(context, 14),
                                  color: AppColors.error,
                                ),
                                SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                                Text(
                                  '전체삭제',
                                  style: AppTextStyles.chipSmall(context, color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                      ],
                      Text(
                        '오늘 처리됨',
                        style: AppTextStyles.tableHeader(context),
                      ),
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
                  color: AppColors.error.withValues(alpha: 0.102),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block_outlined,
                  color: AppColors.error,
                  size: ResponsiveUtils.iconSize(context, 32),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),

              // 제목
              Text(
                '반려 확인',
                style: AppTextStyles.sectionTitle(context),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 8)),

              // 설명
              Text(
                '이 발주를 반려하시겠습니까?',
                style: AppTextStyles.emptyState(context),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),

              // 정보 카드
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
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
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: AppTextStyles.sectionSubtitle(context).copyWith(
                          color: AppColors.textTertiary,
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
                            AppBanner.show(scaffoldContext, '반려 처리되었습니다', type: BannerType.success);
                            await purchaseProvider.fetchPendingPurchases(
                              employee: userProvider.employee,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
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
                        style: AppTextStyles.sectionSubtitle(context).copyWith(
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
  
  // 커스텀 기간 선택 다이얼로그
  void _showDateRangePicker() async {
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: ResponsiveUtils.getScreenWidth(context) * 0.9,
                constraints: BoxConstraints(
                  maxHeight: ResponsiveUtils.getScreenHeight(context) * 0.7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight, width: 0.5),
                  boxShadow: AppShadows.strongShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 커스텀 헤더
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.white,
                            size: ResponsiveUtils.iconSize(context, 24),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                          Text(
                            '기간 선택',
                            style: AppTextStyles.cardTitle(context).copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 날짜 선택 영역
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 현재 선택된 기간 표시
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '선택된 기간',
                                    style: AppTextStyles.inputLabel(context),
                                  ),
                                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                  Text(
                                    tempStartDate != null && tempEndDate != null
                                        ? '${DateFormat('yyyy년 M월 d일').format(tempStartDate!)} - ${DateFormat('yyyy년 M월 d일').format(tempEndDate!)}'
                                        : '기간을 선택해주세요',
                                    style: AppTextStyles.sectionSubtitle(context).copyWith(
                                      color: AppColors.primary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                            
                            // 시작일 선택
                            _buildDateSelector(
                              context,
                              '시작일',
                              tempStartDate,
                              (date) {
                                setDialogState(() {
                                  tempStartDate = date;
                                  // 시작일이 종료일보다 늦으면 종료일을 시작일로 설정
                                  if (tempEndDate != null && date.isAfter(tempEndDate!)) {
                                    tempEndDate = date;
                                  }
                                });
                              },
                            ),
                            
                            SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                            
                            // 종료일 선택
                            _buildDateSelector(
                              context,
                              '종료일',
                              tempEndDate,
                              (date) {
                                setDialogState(() {
                                  tempEndDate = date;
                                  // 종료일이 시작일보다 이르면 시작일을 종료일로 설정
                                  if (tempStartDate != null && date.isBefore(tempStartDate!)) {
                                    tempStartDate = date;
                                  }
                                });
                              },
                            ),
                            
                            SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                            
                            // 빠른 선택 버튼들
                            Wrap(
                              spacing: ResponsiveUtils.spacing(context, 8),
                              runSpacing: ResponsiveUtils.spacing(context, 8),
                              children: [
                                _buildQuickSelectButton(context, '오늘', () {
                                  final today = DateTime.now();
                                  setDialogState(() {
                                    tempStartDate = today;
                                    tempEndDate = today;
                                  });
                                }),
                                _buildQuickSelectButton(context, '1주일', () {
                                  final today = DateTime.now();
                                  setDialogState(() {
                                    tempStartDate = today.subtract(const Duration(days: 7));
                                    tempEndDate = today;
                                  });
                                }),
                                _buildQuickSelectButton(context, '1개월', () {
                                  final today = DateTime.now();
                                  setDialogState(() {
                                    tempStartDate = DateTime(today.year, today.month - 1, today.day);
                                    tempEndDate = today;
                                  });
                                }),
                                _buildQuickSelectButton(context, '3개월', () {
                                  final today = DateTime.now();
                                  setDialogState(() {
                                    tempStartDate = DateTime(today.year, today.month - 3, today.day);
                                    tempEndDate = today;
                                  });
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 버튼 영역
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveUtils.spacing(context, 14),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: AppTextStyles.sectionSubtitle(context).copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: tempStartDate != null && tempEndDate != null
                                  ? () => Navigator.of(context).pop(true)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveUtils.spacing(context, 14),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                '적용',
                                style: AppTextStyles.sectionSubtitle(context).copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && tempStartDate != null && tempEndDate != null) {
      setState(() {
        _startDate = tempStartDate;
        _endDate = tempEndDate;
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

  // 날짜 선택 위젯 생성
  Widget _buildDateSelector(
    BuildContext context,
    String label,
    DateTime? selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.inputLabel(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.gray800,
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 8)),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              locale: const Locale('ko', 'KR'),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: AppColors.primary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedDate != null ? AppColors.primary : AppColors.border,
                width: selectedDate != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: selectedDate != null ? AppColors.primary : AppColors.gray400,
                  size: ResponsiveUtils.iconSize(context, 20),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                Text(
                  selectedDate != null
                      ? DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(selectedDate)
                      : '날짜를 선택해주세요',
                  style: AppTextStyles.sectionSubtitle(context).copyWith(
                    fontWeight: FontWeight.w500,
                    color: selectedDate != null
                        ? AppColors.textPrimary
                        : AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 빠른 선택 버튼 생성
  Widget _buildQuickSelectButton(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 16),
          vertical: ResponsiveUtils.spacing(context, 8),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.inputLabel(context).copyWith(
          color: AppColors.primary,
        ),
      ),
    );
  }

  // 기간 초기화 (기본 1개월로 재설정)
  void _resetDateRange() async {
    setState(() {
      // 기본 날짜 설정 (최근 1개월)로 초기화
      _endDate = DateTime.now();
      _startDate = DateTime(_endDate!.year, _endDate!.month - 1, _endDate!.day);
    });

    // 초기화된 기간으로 데이터 다시 로드
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

  // ===============================================
  // CRUD 기능 (관리자 전용)
  // ===============================================

  // 관리자 권한 체크 함수
  bool _isAppAdmin() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final roles = UserRoleHelper.getRoles(employee);

    return UserRoleHelper.isAppAdmin(roles);
  }

  // 품목 수정 함수
  Future<void> _updatePurchaseItem({
    required int itemId,
    required String itemName,
    required String specification,
    required int quantity,
    required double unitPrice,
  }) async {
    if (!_isAppAdmin()) {
      if (mounted) {
        AppBanner.show(context, '권한이 없습니다. 관리자만 수정 가능합니다.', type: BannerType.warning);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // 총액 계산
      final totalAmount = quantity * unitPrice;

      await supabase.from('purchase_request_items').update({
        'item_name': itemName,
        'specification': specification,
        'quantity': quantity,
        'unit_price_value': unitPrice,
        'amount_value': totalAmount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', itemId);

      if (mounted) {
        AppBanner.show(context, '품목이 수정되었습니다', type: BannerType.success);
      }

      // 데이터 새로고침
      await _refreshCompletedData();
    } catch (e) {
      if (mounted) {
        AppBanner.show(context, '품목 수정 중 오류가 발생했습니다', type: BannerType.error);
      }
    }
  }

  // 품목 삭제 함수  
  Future<void> _deletePurchaseItem(int itemId, String orderNumber) async {
    if (!_isAppAdmin()) {
      if (mounted) {
        AppBanner.show(context, '권한이 없습니다. 관리자만 삭제 가능합니다.', type: BannerType.warning);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('purchase_request_items').delete().eq('id', itemId);

      if (mounted) {
        AppBanner.show(context, '품목이 삭제되었습니다', type: BannerType.success);
      }

      // 해당 발주의 남은 품목 확인
      final remainingItems = await supabase
          .from('purchase_request_items')
          .select()
          .eq('purchase_order_number', orderNumber);

      // 품목이 모두 삭제되면 헤더도 삭제
      if (remainingItems.isEmpty) {
        await supabase
            .from('purchase_requests')
            .delete()
            .eq('purchase_order_number', orderNumber);
      }

      // 데이터 새로고침
      await _refreshCompletedData();
    } catch (e) {
      if (mounted) {
        AppBanner.show(context, '품목 삭제 중 오류가 발생했습니다', type: BannerType.error);
      }
    }
  }

  // 완료된 데이터 새로고침 함수
  Future<void> _refreshCompletedData() async {
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

  // 수정 다이얼로그
  void _showEditDialog(dynamic item) {
    if (!_isAppAdmin()) {
      AppBanner.show(context, '권한이 없습니다. 관리자만 수정 가능합니다.', type: BannerType.warning);
      return;
    }

    final TextEditingController itemNameController = 
        TextEditingController(text: item.itemName);
    final TextEditingController specificationController = 
        TextEditingController(text: item.specification);
    final TextEditingController quantityController = 
        TextEditingController(text: item.quantity.toString());
    final TextEditingController unitPriceController = 
        TextEditingController(text: item.unitPriceValue.toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: ResponsiveUtils.spacing(context, 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
            border: Border.all(color: AppColors.borderLight, width: 0.5),
            boxShadow: AppShadows.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더 영역
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ResponsiveUtils.spacing(context, 12)),
                    topRight: Radius.circular(ResponsiveUtils.spacing(context, 12)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 8)),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 10)),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: ResponsiveUtils.iconSize(context, 24),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '품목 수정',
                            style: AppTextStyles.sectionTitle(context).copyWith(
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                          Text(
                            '품목 정보를 수정합니다',
                            style: AppTextStyles.emptyState(context).copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: ResponsiveUtils.iconSize(context, 24),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 폼 영역
              Padding(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                child: Column(
                  children: [
                    // 품목명
                    _buildFormField(
                      context: context,
                      controller: itemNameController,
                      label: '품목명',
                      icon: Icons.inventory_2_outlined,
                      hint: '품목명을 입력하세요',
                      required: true,
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    
                    // 규격
                    _buildFormField(
                      context: context,
                      controller: specificationController,
                      label: '규격',
                      icon: Icons.straighten_outlined,
                      hint: '규격을 입력하세요',
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    
                    // 수량과 단가를 나란히 배치
                    Row(
                      children: [
                        // 수량
                        Expanded(
                          child: _buildFormField(
                            context: context,
                            controller: quantityController,
                            label: '수량',
                            icon: Icons.numbers_outlined,
                            hint: '수량',
                            keyboardType: TextInputType.number,
                            suffix: Text(
                              '개',
                              style: AppTextStyles.inputLabel(context).copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                        
                        // 단가
                        Expanded(
                          child: _buildFormField(
                            context: context,
                            controller: unitPriceController,
                            label: '단가',
                            icon: Icons.attach_money_outlined,
                            hint: '단가',
                            keyboardType: TextInputType.number,
                            suffix: Text(
                              '원',
                              style: AppTextStyles.inputLabel(context).copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 32)),
                    
                    // 버튼 영역
                    Row(
                      children: [
                        // 취소 버튼
                        Expanded(
                          child: Container(
                            height: ResponsiveUtils.spacing(context, 48),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.gray300,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.gray700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: AppTextStyles.sectionSubtitle(context),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                        
                        // 수정 버튼
                        Expanded(
                          child: Container(
                            height: ResponsiveUtils.spacing(context, 48),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                              boxShadow: AppShadows.smShadow,
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                final itemName = itemNameController.text.trim();
                                final specification = specificationController.text.trim();
                                final quantity = int.tryParse(quantityController.text) ?? 0;
                                final unitPrice = double.tryParse(unitPriceController.text) ?? 0.0;

                                if (itemName.isEmpty) {
                                  AppBanner.show(context, '품목명을 입력하세요', type: BannerType.error);
                                  return;
                                }

                                if (quantity <= 0) {
                                  AppBanner.show(context, '올바른 수량을 입력하세요', type: BannerType.error);
                                  return;
                                }

                                if (unitPrice < 0) {
                                  AppBanner.show(context, '올바른 단가를 입력하세요', type: BannerType.error);
                                  return;
                                }

                                Navigator.of(context).pop();
                                await _updatePurchaseItem(
                                  itemId: item.id,
                                  itemName: itemName,
                                  specification: specification,
                                  quantity: quantity,
                                  unitPrice: unitPrice,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.save_outlined,
                                    size: ResponsiveUtils.iconSize(context, 18),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                  Text(
                                    '수정 완료',
                                    style: AppTextStyles.sectionSubtitle(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // 폼 필드 빌더 헬퍼 메서드
  Widget _buildFormField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: ResponsiveUtils.iconSize(context, 18),
              color: AppColors.primary,
            ),
            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
            Text(
              label,
              style: AppTextStyles.inputLabel(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.gray700,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: AppTextStyles.emptyState(context).copyWith(
                  color: AppColors.error,
                ),
              ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 8)),
        Container(
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
            border: Border.all(
              color: AppColors.gray200,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTextStyles.sectionSubtitle(context).copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.gray800,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.sectionSubtitle(context).copyWith(
                fontWeight: FontWeight.w400,
                color: AppColors.gray400,
              ),
              suffixIcon: suffix != null
                  ? Padding(
                      padding: EdgeInsets.only(right: ResponsiveUtils.spacing(context, 12)),
                      child: suffix,
                    )
                  : null,
              suffixIconConstraints: BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 16),
                vertical: ResponsiveUtils.spacing(context, 16),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                borderSide: BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                borderSide: BorderSide(
                  color: Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 삭제 확인 다이얼로그
  void _showDeleteDialog(dynamic item, String orderNumber) {
    if (!_isAppAdmin()) {
      AppBanner.show(context, '권한이 없습니다. 관리자만 삭제 가능합니다.', type: BannerType.warning);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: ResponsiveUtils.spacing(context, 360),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
            border: Border.all(color: AppColors.borderLight, width: 0.5),
            boxShadow: AppShadows.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더 영역
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ResponsiveUtils.spacing(context, 20)),
                    topRight: Radius.circular(ResponsiveUtils.spacing(context, 20)),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.errorLight,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                      ),
                      child: Icon(
                        Icons.warning_outlined,
                        color: AppColors.error,
                        size: ResponsiveUtils.iconSize(context, 28),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '품목 삭제',
                            style: AppTextStyles.sectionTitle(context).copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                          Text(
                            '삭제된 데이터는 복구할 수 없습니다',
                            style: AppTextStyles.emptyState(context).copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 내용 영역
              Padding(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                child: Column(
                  children: [
                    // 삭제될 품목 정보
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                        border: Border.all(
                          color: AppColors.gray200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: ResponsiveUtils.iconSize(context, 18),
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                              Text(
                                '삭제할 품목',
                                style: AppTextStyles.inputLabel(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                          Text(
                            item.itemName,
                            style: AppTextStyles.sectionSubtitle(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray800,
                            ),
                          ),
                          if (item.specification.isNotEmpty) ...[
                            SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                            Text(
                              '규격: ${item.specification}',
                              style: AppTextStyles.inputLabel(context).copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                          Text(
                            '수량: ${item.quantity}개 | 단가: ${item.unitPriceValue.toStringAsFixed(0)}원',
                            style: AppTextStyles.inputLabel(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    
                    // 확인 메시지
                    Text(
                      '정말로 이 품목을 삭제하시겠습니까?',
                      style: AppTextStyles.sectionSubtitle(context).copyWith(
                        color: AppColors.gray800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                        border: Border.all(
                          color: AppColors.errorLight,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: ResponsiveUtils.iconSize(context, 16),
                            color: AppColors.error,
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                          Expanded(
                            child: Text(
                              '삭제된 데이터는 되돌릴 수 없습니다',
                              style: AppTextStyles.cardCaption(context).copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                    
                    // 버튼 영역
                    Row(
                      children: [
                        // 취소 버튼
                        Expanded(
                          child: Container(
                            height: ResponsiveUtils.spacing(context, 48),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.gray300,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.gray700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: AppTextStyles.sectionSubtitle(context),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                        
                        // 삭제 버튼
                        Expanded(
                          child: Container(
                            height: ResponsiveUtils.spacing(context, 48),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                              boxShadow: AppShadows.smShadow,
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _deletePurchaseItem(item.id, orderNumber);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: ResponsiveUtils.iconSize(context, 18),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                  Text(
                                    '삭제하기',
                                    style: AppTextStyles.sectionSubtitle(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // 발주 전체 삭제 확인 다이얼로그
  void _showBulkDeleteOrderDialog(PurchaseOrderGroup group) {
    if (!_isAppAdmin()) {
      AppBanner.show(context, '권한이 없습니다. 관리자만 삭제 가능합니다.', type: BannerType.warning);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: ResponsiveUtils.spacing(context, 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
            border: Border.all(color: AppColors.borderLight, width: 0.5),
            boxShadow: AppShadows.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더 영역
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ResponsiveUtils.spacing(context, 20)),
                    topRight: Radius.circular(ResponsiveUtils.spacing(context, 20)),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.errorLight,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                      ),
                      child: Icon(
                        Icons.delete_sweep_outlined,
                        color: AppColors.error,
                        size: ResponsiveUtils.iconSize(context, 32),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '발주 전체 삭제',
                            style: AppTextStyles.sectionTitle(context).copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                          Text(
                            '발주의 모든 품목이 삭제됩니다',
                            style: AppTextStyles.emptyState(context).copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 내용 영역
              Padding(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 24)),
                child: Column(
                  children: [
                    // 삭제될 발주 정보
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                        border: Border.all(
                          color: AppColors.gray200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_outlined,
                                size: ResponsiveUtils.iconSize(context, 18),
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                              Text(
                                '삭제할 발주',
                                style: AppTextStyles.inputLabel(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                          Text(
                            group.purchaseOrderNumber,
                            style: AppTextStyles.sectionSubtitle(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray800,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                          Text(
                            '업체: ${group.vendorName}',
                            style: AppTextStyles.inputLabel(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                          Text(
                            '품목 수: ${group.items.length}개 | 총액: ₩${currencyFormat.format(group.totalAmount)}',
                            style: AppTextStyles.inputLabel(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                    
                    // 확인 메시지
                    Text(
                      '이 발주의 모든 품목을 삭제하시겠습니까?',
                      style: AppTextStyles.sectionSubtitle(context).copyWith(
                        color: AppColors.gray800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                        border: Border.all(
                          color: AppColors.errorLight,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_outlined,
                            size: ResponsiveUtils.iconSize(context, 16),
                            color: AppColors.error,
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                          Expanded(
                            child: Text(
                              '발주 헤더와 모든 품목이 영구적으로 삭제됩니다',
                              style: AppTextStyles.cardCaption(context).copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                    
                    // 버튼 영역
                    Row(
                      children: [
                        // 취소 버튼
                        Expanded(
                          child: Container(
                            height: ResponsiveUtils.spacing(context, 48),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.gray300,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.gray700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: AppTextStyles.sectionSubtitle(context),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                        
                        // 전체삭제 버튼
                        Expanded(
                          child: Container(
                            height: ResponsiveUtils.spacing(context, 48),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                              boxShadow: AppShadows.smShadow,
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _deleteBulkPurchaseOrder(group);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_sweep_outlined,
                                    size: ResponsiveUtils.iconSize(context, 18),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                  Text(
                                    '전체삭제',
                                    style: AppTextStyles.sectionSubtitle(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // 발주 전체 삭제 함수
  Future<void> _deleteBulkPurchaseOrder(PurchaseOrderGroup group) async {
    if (!_isAppAdmin()) {
      if (mounted) {
        AppBanner.show(context, '권한이 없습니다. 관리자만 삭제 가능합니다.', type: BannerType.warning);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      
      // 트랜잭션으로 처리: 모든 품목 삭제 후 헤더 삭제
      
      // 1. 모든 품목 삭제
      await supabase
          .from('purchase_request_items')
          .delete()
          .eq('purchase_order_number', group.purchaseOrderNumber);
      
      // 2. 헤더 삭제
      await supabase
          .from('purchase_requests')
          .delete()
          .eq('purchase_order_number', group.purchaseOrderNumber);

      if (mounted) {
        AppBanner.show(context, '발주 "${group.purchaseOrderNumber}"가 완전히 삭제되었습니다', type: BannerType.success);

        // 데이터 새로고침
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        await purchaseProvider.fetchCompletedPurchases(
          employee: userProvider.employee,
          startDate: _startDate,
          endDate: _endDate,
        );
      }
    } catch (e) {
      if (mounted) {
        AppBanner.show(context, '삭제 중 오류가 발생했습니다: $e', type: BannerType.error);
      }
    }
  }
}
