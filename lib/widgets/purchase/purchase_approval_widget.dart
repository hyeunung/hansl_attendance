import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/purchase_request.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';
import 'purchase_edit_sheets.dart';
import '../../utils/user_role_helper.dart';
import '../../widgets/common/notification_banner_widget.dart';
import '../adaptive/detail_pane.dart';
import '../adaptive/pane_dialogs.dart';

class PurchaseApprovalWidget extends StatefulWidget {
  const PurchaseApprovalWidget({super.key, this.initialSearchQuery});

  final String? initialSearchQuery; // 알림에서 진입 시 해당 발주번호로 검색된 상태로 표시


  @override
  State<PurchaseApprovalWidget> createState() => _PurchaseApprovalWidgetState();
}

class _PurchaseApprovalWidgetState extends State<PurchaseApprovalWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
    _searchController.text = widget.initialSearchQuery ?? '';

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
    final sortedItems = group.items.toList()
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

    // 펼친 폴더블: 오른쪽 패널을 채우는 화면으로 열린다 (폰은 기존 다이얼로그)
    DetailPane.dialog<void>(
      context,
      key: 'po-detail-${group.purchaseOrderNumber}',
      builder: (dialogContext) => PaneDialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 16),
          vertical: ResponsiveUtils.spacing(context, 40),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveUtils.spacing(context, 14),
                  ResponsiveUtils.spacing(context, 10),
                  ResponsiveUtils.spacing(context, 10),
                  ResponsiveUtils.spacing(context, 10),
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '발주 상세정보',
                            style: AppTextStyles.listSubtitle(context),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            group.purchaseOrderNumber,
                            style: AppTextStyles.appBarTitle(context),
                          ),
                        ],
                      ),
                    ),
                    if ((group.paymentCategory ?? '').isNotEmpty) ...[
                      StatusChip(
                        label: group.paymentCategory!,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    ],
                    InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 본문
              Flexible(
                child: Container(
                  color: AppColors.backgroundPrimary,
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveUtils.spacing(context, 12),
                    ),
                    children: [
                      FlatCard(
                        child: Column(
                          children: [
                            FlatCardHeader(
                              title: '기본 정보',
                              icon: Icons.info_outline,
                              iconColor: AppColors.primary,
                            ),
                            FlatInfoRow(
                              label: '요청자',
                              value: group.requesterName,
                            ),
                            FlatInfoRow(
                              label: '업체명',
                              value: group.vendorName,
                            ),
                            FlatInfoRow(
                              label: '요청일',
                              value: DateFormat(
                                'yyyy.MM.dd',
                              ).format(group.requestDate),
                            ),
                            if (group.items.isNotEmpty &&
                                group.headerItem.deliveryRequestDate !=
                                    DateTime(1970))
                              FlatInfoRow(
                                label: '입고요청일',
                                value: DateFormat('yyyy.MM.dd').format(
                                  group.headerItem.deliveryRequestDate,
                                ),
                              ),
                            if (group.headerItem.projectVendor != null &&
                                group.headerItem.projectVendor!.isNotEmpty)
                              FlatInfoRow(
                                label: 'PJ업체',
                                value: group.headerItem.projectVendor!,
                              ),
                            if (group.headerItem.salesOrderNumber != null &&
                                group.headerItem.salesOrderNumber!.isNotEmpty)
                              FlatInfoRow(
                                label: '수주번호',
                                value: group.headerItem.salesOrderNumber!,
                              ),
                            if (group.headerItem.projectItem != null &&
                                group.headerItem.projectItem!.isNotEmpty)
                              FlatInfoRow(
                                label: 'Item',
                                value: group.headerItem.projectItem!,
                              ),
                          ],
                        ),
                      ),
                      FlatCard(
                        child: Column(
                          children: [
                            FlatCardHeader(
                              title: '품목',
                              icon: Icons.inventory_2_outlined,
                              iconColor: AppColors.primary,
                              trailing: Text(
                                '${sortedItems.length}개',
                                style: AppTextStyles.listSubtitle(context),
                              ),
                            ),
                            for (final item in sortedItems)
                              _buildOrderDetailItemRow(
                                context,
                                item,
                                group.purchaseOrderNumber,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 발주 상세 다이얼로그의 품목 행
  Widget _buildOrderDetailItemRow(
    BuildContext context,
    dynamic item,
    String orderNumber,
  ) {
    // 규격 · 수량 · 단가를 한 줄로 요약
    final summary = [
      if (item.specification.isNotEmpty) item.specification,
      '${item.quantity}개',
      CurrencyFormatter.format(item.unitPriceValue, item.currency),
    ].join(' · ');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacing(context, 14),
        vertical: ResponsiveUtils.spacing(context, 8),
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.lineNumber}. '
                  '${item.itemName.isNotEmpty ? item.itemName : "품목명 없음"}',
                  style: AppTextStyles.tableCell(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
              Text(
                CurrencyFormatter.format(item.amountValue, item.currency),
                style: AppTextStyles.tableCell(
                  context,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 3)),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: AppTextStyles.listSubtitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 수정/삭제 버튼 (관리자만 표시)
              if (_isAppAdmin()) ...[
                SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                _buildDetailIconButton(
                  context,
                  icon: Icons.edit_outlined,
                  color: AppColors.textSecondary,
                  tooltip: '품목 수정',
                  onTap: () => _showEditDialog(item),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                _buildDetailIconButton(
                  context,
                  icon: Icons.delete_outline,
                  color: AppColors.error,
                  tooltip: '품목 삭제',
                  onTap: () => _showDeleteDialog(item, orderNumber),
                ),
              ],
            ],
          ),
          if (item.remark != null && item.remark!.isNotEmpty) ...[
            SizedBox(height: ResponsiveUtils.spacing(context, 2)),
            Text(
              item.remark!,
              style: AppTextStyles.listSubtitle(context),
            ),
          ],
        ],
      ),
    );
  }

  /// 상세 다이얼로그 품목 행의 작은 아이콘 버튼 (28x28, radius 8)
  Widget _buildDetailIconButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
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
                horizontal: ResponsiveUtils.spacing(context, 16),
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
                            : AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _tabController.index == 0
                              ? AppColors.primary
                              : AppColors.border,
                        ),
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
                            : AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _tabController.index == 1
                              ? AppColors.primary
                              : AppColors.border,
                        ),
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
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
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
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
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
                horizontal: ResponsiveUtils.spacing(context, 16),
                vertical: ResponsiveUtils.spacing(context, 20),
              ),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: ResponsiveUtils.iconSize(context, 40),
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
              vertical: ResponsiveUtils.spacing(context, 12),
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
                horizontal: ResponsiveUtils.spacing(context, 16),
                vertical: ResponsiveUtils.spacing(context, 20),
              ),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: ResponsiveUtils.iconSize(context, 40),
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
                horizontal: ResponsiveUtils.spacing(context, 16),
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
                          horizontal: ResponsiveUtils.spacing(context, 16),
                          vertical: ResponsiveUtils.spacing(context, 20),
                        ),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  _searchQuery.isNotEmpty ? Icons.search_off : Icons.task_alt,
                                  size: ResponsiveUtils.iconSize(context, 40),
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
                          bottom: ResponsiveUtils.spacing(context, 12),
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
        ? AppColors.errorLight // 연붉은색
        : Colors.white;

    // 승인 권한/단계
    final bool canMiddle = canApproveMiddle(purchaseRoles) &&
        group.middleManagerStatus == 'pending';
    final bool canFinal = canApproveFinal(purchaseRoles, group.paymentCategory) &&
        group.middleManagerStatus == 'approved' &&
        group.finalManagerStatus == 'pending';

    // 규격 · 수량 한 줄 요약
    final String itemSummary = [
      if (headerItem.specification.isNotEmpty) headerItem.specification,
      '${headerItem.quantity}개',
    ].join(' · ');

    return FlatCard(
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          border: isPreProgress
              ? const Border(left: BorderSide(color: AppColors.error, width: 3))
              : null,
        ),
        child: InkWell(
          onTap: () => _showOrderDetails(context, group),
          child: Column(
            children: [
              FlatCardHeader(
                title: group.purchaseOrderNumber,
                icon: Icons.receipt_long_outlined,
                iconColor: AppColors.primary,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPreProgress) ...[
                      const StatusChip(label: '선진행', color: AppColors.error),
                      SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                    ],
                    StatusChip(
                      label: group.paymentCategory ?? '',
                      color: categoryTextColor,
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                    StatusChip(label: statusLabel, color: statusTextColor),
                  ],
                ),
              ),
              FlatInfoRow(label: '요청자', value: group.requesterName),
              FlatInfoRow(label: '업체', value: group.vendorName),
              FlatInfoRow(
                label: '품목',
                value: headerItem.itemName.isNotEmpty
                    ? headerItem.itemName
                    : '품목명 없음',
                trailing: group.additionalItemCount > 0
                    ? StatusChip(
                        label: '외 ${group.additionalItemCount}개',
                        color: AppColors.primary,
                      )
                    : null,
              ),
              FlatInfoRow(label: '규격/수량', value: itemSummary),
              // 하단: 총 금액 + 승인/반려 버튼
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 14),
                  vertical: ResponsiveUtils.spacing(context, 8),
                ),
                child: Row(
                  children: [
                    Text('총 금액', style: AppTextStyles.listSubtitle(context)),
                    SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                    Expanded(
                      child: Text(
                        CurrencyFormatter.format(
                          group.totalAmount,
                          group.currency,
                        ),
                        style: AppTextStyles.tableCell(
                          context,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canMiddle)
                      ElevatedButton(
                        onPressed: () => _runApproval(
                          context: context,
                          group: group,
                          userProvider: userProvider,
                          purchaseProvider: purchaseProvider,
                          isFinal: false,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 12),
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
                    if (canFinal)
                      ElevatedButton(
                        onPressed: () => _runApproval(
                          context: context,
                          group: group,
                          userProvider: userProvider,
                          purchaseProvider: purchaseProvider,
                          isFinal: true,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 12),
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
                    if (canMiddle || canFinal) ...[
                      SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                      OutlinedButton(
                        onPressed: () => _showRejectDialog(
                          context,
                          group,
                          purchaseRoles,
                          userProvider,
                          purchaseProvider,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 12),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1차/최종 승인 공통 흐름: 확인 다이얼로그 → 로딩 → 결과 안내 → 목록 갱신
  Future<void> _runApproval({
    required BuildContext context,
    required PurchaseOrderGroup group,
    required UserProvider userProvider,
    required PurchaseProvider purchaseProvider,
    required bool isFinal,
  }) async {
    final title = isFinal ? '최종 승인' : '1차 승인';
    final color = isFinal ? AppColors.primary : AppColors.success;
    final icon = isFinal ? Icons.verified_outlined : Icons.check_circle_outline;

    // 승인 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        title: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isFinal ? '발주를 최종 승인하시겠습니까?' : '발주를 승인하시겠습니까?',
              style: AppTextStyles.cardBody(context),
            ),
            const SizedBox(height: 10),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  FlatInfoRow(label: '발주번호', value: group.purchaseOrderNumber),
                  FlatInfoRow(label: '요청자', value: group.requesterName),
                  FlatInfoRow(label: '업체', value: group.vendorName),
                  FlatInfoRow(
                    label: '총 금액',
                    value: CurrencyFormatter.format(
                      group.totalAmount,
                      group.currency,
                    ),
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(isFinal ? '최종 승인' : '승인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // BuildContext 저장
    final scaffoldContext = context;
    BuildContext? loadingContext;
    // 로딩 다이얼로그 표시
    showDialog(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingContext = dialogContext;
        return const Center(child: CircularProgressIndicator());
      },
    );
    bool success = false;
    try {
      success = isFinal
          ? await purchaseProvider.approveFinal(group.purchaseOrderNumber)
          : await purchaseProvider.approveMiddle(group.purchaseOrderNumber);
    } finally {
      // 로딩 다이얼로그 닫기
      if (loadingContext != null && loadingContext!.mounted) {
        Navigator.of(loadingContext!).pop();
      }
    }
    if (!scaffoldContext.mounted) return;

    if (success) {
      // 성공 안내
      showDialog(
        context: scaffoldContext,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          title: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: color),
              const SizedBox(width: 8),
              Text('$title 완료'),
            ],
          ),
          content: Text(
            '발주번호: ${group.purchaseOrderNumber}',
            style: AppTextStyles.cardBody(context),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(backgroundColor: color),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      // 실시간 데이터 업데이트
      await purchaseProvider.fetchPendingPurchases(
        employee: userProvider.employee,
      );
    } else {
      AppBanner.show(
        scaffoldContext,
        '$title 실패: ${purchaseProvider.error ?? "알 수 없는 오류"}',
        type: BannerType.error,
      );
    }
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

    return FlatCard(
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          border: isPreProgress
              ? const Border(left: BorderSide(color: AppColors.error, width: 3))
              : null,
        ),
        child: InkWell(
          onTap: () => _showOrderDetails(context, group),
          child: Column(
            children: [
              FlatCardHeader(
                title: group.purchaseOrderNumber,
                icon: Icons.task_alt,
                iconColor: statusTextColor,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                      label: group.paymentCategory ?? '',
                      color: categoryTextColor,
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                    StatusChip(label: statusLabel, color: statusTextColor),
                  ],
                ),
              ),
              FlatInfoRow(label: '요청자', value: group.requesterName),
              FlatInfoRow(label: '업체', value: group.vendorName),
              FlatInfoRow(
                label: '품목',
                value: headerItem.itemName.isNotEmpty
                    ? headerItem.itemName
                    : '품목명 없음',
                trailing: group.additionalItemCount > 0
                    ? StatusChip(
                        label: '외 ${group.additionalItemCount}개',
                        color: AppColors.primary,
                      )
                    : null,
              ),
              // 하단: 총 금액 + 처리 시점 + 전체삭제
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 14),
                  vertical: ResponsiveUtils.spacing(context, 8),
                ),
                child: Row(
                  children: [
                    Text('총 금액', style: AppTextStyles.listSubtitle(context)),
                    SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                    Text(
                      CurrencyFormatter.format(
                        group.totalAmount,
                        group.currency,
                      ),
                      style: AppTextStyles.tableCell(
                        context,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '오늘 처리됨',
                      style: AppTextStyles.listSubtitle(context),
                    ),
                    // 관리자만 전체삭제 버튼 표시
                    if (_isAppAdmin()) ...[
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      InkWell(
                        onTap: () => _showBulkDeleteOrderDialog(group),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 8),
                            vertical: ResponsiveUtils.spacing(context, 4),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4),
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
                              SizedBox(
                                width: ResponsiveUtils.spacing(context, 4),
                              ),
                              Text(
                                '전체삭제',
                                style: AppTextStyles.chipSmall(
                                  context,
                                  color: AppColors.error,
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
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        title: const Row(
          children: [
            Icon(Icons.block_outlined, size: 18, color: AppColors.error),
            SizedBox(width: 8),
            Text('반려 확인'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('이 발주를 반려하시겠습니까?', style: AppTextStyles.cardBody(context)),
            const SizedBox(height: 10),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  FlatInfoRow(label: '발주번호', value: group.purchaseOrderNumber),
                  FlatInfoRow(label: '요청자', value: group.requesterName),
                  FlatInfoRow(label: '업체', value: group.vendorName),
                  FlatInfoRow(
                    label: '금액',
                    value: CurrencyFormatter.formatWon(
                      group.totalAmount,
                      group.currency,
                    ),
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final isMiddleManager = canApproveMiddle(purchaseRoles) &&
                  group.middleManagerStatus == 'pending';

              final success = await purchaseProvider.rejectPurchase(
                group.purchaseOrderNumber,
                isMiddleManager: isMiddleManager,
                reason: '확인 후 반려',
              );

              if (success && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  AppBanner.show(context, '반려 처리되었습니다', type: BannerType.success);
                  await purchaseProvider.fetchPendingPurchases(
                    employee: userProvider.employee,
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('반려'),
          ),
        ],
      ),
    );
  }
  
  // 커스텀 기간 선택 다이얼로그
  // 기간 선택 다이얼로그 (Enterprise Neutral: 흰 헤더, 카드 행, 컴팩트 버튼)
  void _showDateRangePicker() async {
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasRange = tempStartDate != null && tempEndDate != null;
            final rangeText = hasRange
                ? '${DateFormat('yyyy.MM.dd').format(tempStartDate!)} ~ '
                    '${DateFormat('yyyy.MM.dd').format(tempEndDate!)}'
                : '기간을 선택하세요';

            void setRange(DateTime start, DateTime end) {
              setDialogState(() {
                tempStartDate = start;
                tempEndDate = end;
              });
            }

            return Dialog(
              clipBehavior: Clip.antiAlias,
              insetPadding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 16),
                vertical: ResponsiveUtils.spacing(context, 40),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveUtils.spacing(context, 14),
                      ResponsiveUtils.spacing(context, 10),
                      ResponsiveUtils.spacing(context, 10),
                      ResponsiveUtils.spacing(context, 10),
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '기간 선택',
                            style: AppTextStyles.appBarTitle(context),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 본문
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveUtils.spacing(context, 14),
                      ResponsiveUtils.spacing(context, 12),
                      ResponsiveUtils.spacing(context, 14),
                      ResponsiveUtils.spacing(context, 4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 선택된 기간
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 12),
                            vertical: ResponsiveUtils.spacing(context, 8),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '선택된 기간',
                                style: AppTextStyles.listSubtitle(context),
                              ),
                              const Spacer(),
                              Text(
                                rangeText,
                                style: AppTextStyles.tableCell(
                                  context,
                                  color: hasRange
                                      ? AppColors.primary
                                      : AppColors.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                        // 시작일 / 종료일 (한 행)
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateSelector(
                                context,
                                '시작일',
                                tempStartDate,
                                (date) {
                                  setDialogState(() {
                                    tempStartDate = date;
                                    if (tempEndDate != null &&
                                        date.isAfter(tempEndDate!)) {
                                      tempEndDate = date;
                                    }
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                            Expanded(
                              child: _buildDateSelector(
                                context,
                                '종료일',
                                tempEndDate,
                                (date) {
                                  setDialogState(() {
                                    tempEndDate = date;
                                    if (tempStartDate != null &&
                                        date.isBefore(tempStartDate!)) {
                                      tempStartDate = date;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                        // 빠른 선택
                        Text('빠른 선택', style: AppTextStyles.listSubtitle(context)),
                        SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                        Wrap(
                          spacing: ResponsiveUtils.spacing(context, 6),
                          runSpacing: ResponsiveUtils.spacing(context, 6),
                          children: [
                            _buildQuickSelectButton(context, '오늘', () {
                              final today = DateTime.now();
                              setRange(today, today);
                            }),
                            _buildQuickSelectButton(context, '1주일', () {
                              final today = DateTime.now();
                              setRange(
                                today.subtract(const Duration(days: 7)),
                                today,
                              );
                            }),
                            _buildQuickSelectButton(context, '1개월', () {
                              final today = DateTime.now();
                              setRange(
                                DateTime(today.year, today.month - 1, today.day),
                                today,
                              );
                            }),
                            _buildQuickSelectButton(context, '3개월', () {
                              final today = DateTime.now();
                              setRange(
                                DateTime(today.year, today.month - 3, today.day),
                                today,
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 버튼
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveUtils.spacing(context, 12),
                      ResponsiveUtils.spacing(context, 4),
                      ResponsiveUtils.spacing(context, 12),
                      ResponsiveUtils.spacing(context, 8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: hasRange
                              ? () => Navigator.of(dialogContext).pop(true)
                              : null,
                          child: const Text('적용'),
                        ),
                      ],
                    ),
                  ),
                ],
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
      if (!mounted) return;
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

  /// 기간 선택 다이얼로그의 날짜 필드 (높이 40, radius 8)
  Widget _buildDateSelector(
    BuildContext context,
    String label,
    DateTime? selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.listSubtitle(context)),
        SizedBox(height: ResponsiveUtils.spacing(context, 4)),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            // 전역 datePickerTheme을 그대로 사용 (개별 테마 덮어쓰기 금지)
            final picked = await showDatePicker(
              initialEntryMode: DatePickerEntryMode.calendarOnly,
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              locale: const Locale('ko', 'KR'),
            );
            if (picked != null) onDateSelected(picked);
          },
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 10),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectedDate != null ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: selectedDate != null
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  size: ResponsiveUtils.iconSize(context, 14),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(selectedDate)
                        : '날짜 선택',
                    style: AppTextStyles.tableCell(
                      context,
                      color: selectedDate != null
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 기간 빠른 선택 칩 (높이 28, radius 8)
  Widget _buildQuickSelectButton(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 10),
          vertical: 0,
        ),
        minimumSize: const Size(0, 28),
      ),
      child: Text(
        label,
        style: AppTextStyles.compactLabel(context).copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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

  // 수정 바텀시트
  void _showEditDialog(PurchaseRequest item) {
    if (!_isAppAdmin()) {
      AppBanner.show(context, '권한이 없습니다. 관리자만 수정 가능합니다.', type: BannerType.warning);
      return;
    }

    showPurchaseItemEditSheet(
      context: context,
      item: item,
      onSave: ({
        required String itemName,
        required String specification,
        required int quantity,
        required double unitPrice,
      }) =>
          _updatePurchaseItem(
        itemId: item.id,
        itemName: itemName,
        specification: specification,
        quantity: quantity,
        unitPrice: unitPrice,
      ),
    );
  }

  // 삭제 확인 다이얼로그
  void _showDeleteDialog(dynamic item, String orderNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            SizedBox(width: 8),
            Text('품목 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '정말로 이 품목을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.',
              style: AppTextStyles.cardBody(context),
            ),
            const SizedBox(height: 10),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  FlatInfoRow(label: '품목', value: item.itemName),
                  if (item.specification.isNotEmpty)
                    FlatInfoRow(label: '규격', value: item.specification),
                  FlatInfoRow(label: '수량', value: '${item.quantity}개'),
                  FlatInfoRow(
                    label: '단가',
                    value: CurrencyFormatter.formatWon(
                      item.unitPriceValue,
                      item.currency,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deletePurchaseItem(item.id, orderNumber);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제하기'),
          ),
        ],
      ),
    );
  }

  // 발주 전체 삭제 확인 다이얼로그
  void _showBulkDeleteOrderDialog(PurchaseOrderGroup group) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.error),
            SizedBox(width: 8),
            Text('발주 전체 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '이 발주의 모든 품목을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.',
              style: AppTextStyles.cardBody(context),
            ),
            const SizedBox(height: 10),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  FlatInfoRow(label: '발주번호', value: group.purchaseOrderNumber),
                  FlatInfoRow(label: '업체', value: group.vendorName),
                  FlatInfoRow(label: '품목 수', value: '${group.items.length}개'),
                  FlatInfoRow(
                    label: '총액',
                    value: CurrencyFormatter.format(
                      group.totalAmount,
                      group.currency,
                    ),
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteBulkPurchaseOrder(group);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('전체 삭제'),
          ),
        ],
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
