import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_request.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../utils/responsive_utils.dart';

class PurchaseApprovalWidget extends StatefulWidget {
  const PurchaseApprovalWidget({super.key});

  @override
  State<PurchaseApprovalWidget> createState() => _PurchaseApprovalWidgetState();
}

class _PurchaseApprovalWidgetState extends State<PurchaseApprovalWidget>
    with SingleTickerProviderStateMixin {
  final NumberFormat currencyFormat = NumberFormat('#,###');
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 탭 변경 리스너 추가
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // UI 업데이트를 위한 setState 추가
        setState(() {});

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final purchaseProvider = Provider.of<PurchaseProvider>(
          context,
          listen: false,
        );

        if (_tabController.index == 1) {
          // 처리완료 탭으로 이동 시 금일 처리 데이터 로드
          purchaseProvider.fetchCompletedPurchases(
            employee: userProvider.employee,
          );
        }
      }
    });

    // 위젯 생성 시 자동으로 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final purchaseProvider = Provider.of<PurchaseProvider>(
        context,
        listen: false,
      );

      if (kDebugMode) {
        print('🔄 PurchaseApprovalWidget - 초기 데이터 로드');
        print('📋 employee: ${userProvider.employee}');
      }

      purchaseProvider.fetchPendingPurchases(employee: userProvider.employee);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 승인 권한 체크
  bool canApproveMiddle(List<dynamic> roles) {
    return roles.contains('middle_manager') || roles.contains('app_admin');
  }

  bool canApproveFinal(List<dynamic> roles, String paymentCategory) {
    if (roles.contains('app_admin')) return true;
    if (!roles.contains('final_approver')) return false;

    // final_approver가 있는 경우 세부 권한 체크
    if (roles.contains('raw_material_manager')) {
      return paymentCategory == '발주';
    }
    if (roles.contains('consumable_manager')) {
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
              // 헤더
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      ResponsiveUtils.spacing(context, 16),
                    ),
                    topRight: Radius.circular(
                      ResponsiveUtils.spacing(context, 16),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: ResponsiveUtils.iconSize(context, 24),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    Expanded(
                      child: Text(
                        group.purchaseOrderNumber,
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 결제구분 칩
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 10),
                        vertical: ResponsiveUtils.spacing(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.255),
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.spacing(context, 12),
                        ),
                      ),
                      child: Text(
                        group.paymentCategory,
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: ResponsiveUtils.iconSize(context, 24),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 상세 내역
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                  children: [
                    // 기본 정보
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
                        DateFormat(
                          'yyyy.MM.dd',
                        ).format(group.headerItem.deliveryRequestDate),
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
                    Divider(height: ResponsiveUtils.spacing(context, 32)),

                    // 품목 리스트
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '품목 상세 (${group.items.length}개)',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1C1C1E),
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
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.spacing(context, 8),
                              ),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 품목 번호와 이름 (DB의 line_number 사용)
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
    return Consumer2<PurchaseProvider, UserProvider>(
      builder: (context, purchaseProvider, userProvider, _) {
        final purchaseRoles =
            userProvider.employee?['purchase_role'] as List<dynamic>? ?? [];

        // 사용자 역할에 따른 대기 개수 계산
        int pendingCount = 0;
        String pendingDetail = '';

        if (purchaseRoles.contains('app_admin')) {
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
          if (purchaseRoles.contains('middle_manager')) {
            pendingCount += purchaseProvider.middleManagerPendingCount;
          }
          if (purchaseRoles.contains('final_approver')) {
            if (purchaseRoles.contains('raw_material_manager')) {
              pendingCount += purchaseProvider.rawMaterialPendingCount;
            }
            if (purchaseRoles.contains('consumable_manager')) {
              pendingCount += purchaseProvider.consumablePendingCount;
            }
          }
        }

        return Column(
          children: [
            // 상태별 탭 (대기중/처리완료)
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
                          if (pendingCount > 0) ...[
                            SizedBox(
                              width: ResponsiveUtils.spacing(context, 6),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacing(context, 6),
                                vertical: ResponsiveUtils.spacing(context, 2),
                              ),
                              decoration: BoxDecoration(
                                color: _tabController.index == 0
                                    ? Colors.white.withValues(alpha: 0.255)
                                    : AppColors.primary.withValues(
                                        alpha: 0.153,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingCount',
                                style: ResponsiveUtils.getTextStyle(
                                  context,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _tabController.index == 0
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
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
                ],
              ),
            ),

            // app_admin인 경우 세부 개수 표시
            if (purchaseRoles.contains('app_admin') &&
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
          return const Center(child: CircularProgressIndicator());
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

        final orders = purchaseProvider.pendingOrders;

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
          onRefresh: () => purchaseProvider.fetchPendingPurchases(
            employee: userProvider.employee,
          ),
          child: ListView.builder(
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
        if (purchaseProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
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

        return RefreshIndicator(
          onRefresh: () => purchaseProvider.fetchCompletedPurchases(
            employee: userProvider.employee,
          ),
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 20),
              vertical: ResponsiveUtils.spacing(context, 20),
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final group = orders[index];
              return _buildCompletedCard(context, group);
            },
          ),
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

    if (kDebugMode) {
      print('🎨 카드 렌더링: ${group.purchaseOrderNumber}');
      print('  - 아이템 수: ${group.items.length}');
      print('  - 헤더 아이템: ${headerItem.itemName}');
      print('  - 규격: ${headerItem.specification}');
      print('  - 수량: ${headerItem.quantity}');
      print('  - 라인 넘버: ${headerItem.lineNumber}');
      print('  - 추가 아이템: ${group.additionalItemCount}개');
    }

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
        boxShadow: [AppShadows.card],
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
                      group.paymentCategory,
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

                            if (confirmed == true) {
                              final success = await purchaseProvider
                                  .approveMiddle(group.purchaseOrderNumber);
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('1차 승인 완료')),
                                );
                                await purchaseProvider.fetchPendingPurchases(
                                  employee: userProvider.employee,
                                );
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

                            if (confirmed == true) {
                              final success = await purchaseProvider
                                  .approveFinal(group.purchaseOrderNumber);
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('최종 승인 완료')),
                                );
                                await purchaseProvider.fetchPendingPurchases(
                                  employee: userProvider.employee,
                                );
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
        boxShadow: [AppShadows.card],
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
                      group.paymentCategory,
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
    final TextEditingController reasonController = TextEditingController();

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
                        final isMiddleManager =
                            canApproveMiddle(purchaseRoles) &&
                            group.middleManagerStatus == 'pending';

                        final success = await purchaseProvider.rejectPurchase(
                          group.purchaseOrderNumber,
                          isMiddleManager: isMiddleManager,
                          reason: '확인 후 반려',
                        );

                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('반려 처리되었습니다')),
                          );
                          await purchaseProvider.fetchPendingPurchases(
                            employee: userProvider.employee,
                          );
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
}
