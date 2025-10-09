import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/user_role_helper.dart';
import 'package:intl/intl.dart';

// 입고대기 위젯
class ReceivingWaitingWidget extends StatefulWidget {
  const ReceivingWaitingWidget({super.key});

  @override
  State<ReceivingWaitingWidget> createState() => _ReceivingWaitingWidgetState();
}

class _ReceivingWaitingWidgetState extends State<ReceivingWaitingWidget> {
  final _supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> _itemsByOrder = {};
  final Map<String, bool> _expandedOrders = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReceivingItems();
  }

  Future<void> _loadReceivingItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employee = userProvider.employee;
      final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];
      final userName = employee?['name'] as String? ?? '';
      
      // UserRoleHelper로 권한 체크
      final isAppAdmin = UserRoleHelper.isAppAdmin(purchaseRoles);
      final isMiddleManager = UserRoleHelper.isMiddleManager(purchaseRoles);
      final isFinalApprover = UserRoleHelper.isFinalApprover(purchaseRoles);
      final isPurchaseManager = purchaseRoles.contains('purchase_manager');
      final isCeo = purchaseRoles.contains('ceo');
      
      // 권한별 필터:
      // - purchase_manager: 본인 요청 건만
      // - app_admin, middle_manager, final_approver, ceo: 전체 보기
      // - 그 외: 본인 요청 건만
      final hasFullAccess = isAppAdmin || isMiddleManager || isFinalApprover || isCeo;
      
      // 입고대기: 미입고 AND (선진행 OR 최종승인)
      var query = _supabase
          .from('purchase_requests')
          .select('*, purchase_request_items(*)')
          .eq('is_received', false);  // 미입고만 체크

      // 권한에 따른 필터링: 전체 보기 권한이 없는 경우 본인 것만 조회
      if (!hasFullAccess) {
        query = query.eq('requester_name', userName);
      }

      final response = await query;

      // response is always List<dynamic>, never null from Supabase
        final allPurchases = response as List<dynamic>;
        
        // progress_type 조건으로 필터링: 선진행 OR 최종승인
        final purchases = allPurchases.where((purchase) {
          final progressType = purchase['progress_type'] ?? '';
          final finalStatus = purchase['final_manager_status'] ?? '';
          
          // 선진행은 무조건 포함
          if (progressType.toString().contains('선진행')) return true;
          // 최종승인 완료된 것 포함
          if (finalStatus == 'approved') return true;
          
          return false;
        }).toList();
        Map<String, List<Map<String, dynamic>>> groupedItems = {};

        for (var purchase in purchases) {
          final orderNumber = purchase['purchase_order_number'] as String;
          final items = purchase['purchase_request_items'] as List<dynamic>;
          
          // is_received가 false인 품목들만 필터링 (is_payment_completed 조건 제거)
          final unreceived = items.where((item) => 
            item['is_received'] == false
          ).toList();
          
          if (unreceived.isNotEmpty) {
            groupedItems[orderNumber] = unreceived.map<Map<String, dynamic>>((item) => {
              ...Map<String, dynamic>.from(item as Map),
              'vendor_name': purchase['vendor_name'],
              'requester_name': purchase['requester_name'],
              'request_date': purchase['request_date'],
              'purchase_id': purchase['id'],
            }).toList();
          }
        }

        setState(() {
          _itemsByOrder = groupedItems;
          _isLoading = false;
        });
    } catch (e) {
      // 에러 로깅 제거됨 (Production 코드)
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 품목별 입고완료 처리
  Future<void> _completeReceivingForItem(String orderNumber, int itemId) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employee = userProvider.employee;
      final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];
      final userName = employee?['name'] as String? ?? '';
      
      // 권한 체크: app_admin, pure lead buyer, 또는 본인 요청자만 가능
      bool canComplete = false;
      
      if (UserRoleHelper.isAppAdmin(purchaseRoles) || 
          UserRoleHelper.isPureLeadBuyer(purchaseRoles)) {
        canComplete = true;
      } else {
        // 본인 요청 확인
        final items = _itemsByOrder[orderNumber];
        final item = items?.firstWhere(
          (i) => i['id'] == itemId,
          orElse: () => <String, dynamic>{},
        );
        if (item != null && item.isNotEmpty && item['requester_name'] == userName) {
          canComplete = true;
        }
      }

      if (!canComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('입고 완료 권한이 없습니다')),
        );
        return;
      }

      // purchase_request_items 테이블의 특정 품목 업데이트
      await _supabase
          .from('purchase_request_items')
          .update({
            'is_received': true,
            'received_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId);

      // 해당 발주번호의 모든 품목이 입고완료되었는지 확인
      final remainingItems = await _supabase
          .from('purchase_request_items')
          .select()
          .eq('purchase_order_number', orderNumber)
          .eq('is_received', false);

      // 모든 품목이 입고완료되면 헤더도 업데이트
      if (remainingItems.isEmpty) {
        await _supabase
            .from('purchase_requests')
            .update({
              'is_received': true,
              'received_at': DateTime.now().toIso8601String(),
              'progress_type': '입고 완료',
            })
            .eq('purchase_order_number', orderNumber);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('입고 완료 처리되었습니다')),
        );
      }

      // 데이터 새로고침
      await _loadReceivingItems();
    } catch (e) {
      // 에러 로깅 제겄됨 (Production 코드)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('입고완료 처리 중 오류가 발생했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_itemsByOrder.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: ResponsiveUtils.iconSize(context, 80),
              color: const Color(0xFFE0E0E0),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
            Text(
              '입고대기 항목이 없습니다',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReceivingItems,
      child: ListView.builder(
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
        itemCount: _itemsByOrder.length,
        itemBuilder: (context, index) {
          final orderNumber = _itemsByOrder.keys.elementAt(index);
          final items = _itemsByOrder[orderNumber]!;
          final isExpanded = _expandedOrders[orderNumber] ?? false;
          final firstItem = items.first;
          final dateFormat = DateFormat('yyyy-MM-dd');
          
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final employee = userProvider.employee;
          final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];
          final userName = employee?['name'] as String? ?? '';
          
          // 입고완료 버튼 표시 여부
          final canComplete = UserRoleHelper.isAppAdmin(purchaseRoles) || 
                            UserRoleHelper.isPureLeadBuyer(purchaseRoles) ||
                            firstItem['requester_name'] == userName;

          return Container(
            margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 16)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 헤더 (클릭 가능)
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedOrders[orderNumber] = !isExpanded;
                    });
                  },
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                    bottom: isExpanded ? Radius.zero : Radius.circular(ResponsiveUtils.spacing(context, 16)),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(ResponsiveUtils.spacing(context, 16)),
                        bottom: isExpanded ? Radius.zero : Radius.circular(ResponsiveUtils.spacing(context, 16)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    orderNumber,
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1C1C1E),
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                                  Text(
                                    firstItem['vendor_name'] ?? '업체명 없음',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 14,
                                      color: const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${firstItem['requester_name']} · ${dateFormat.format(DateTime.parse(firstItem['request_date']))}',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 13,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacing(context, 8),
                            vertical: ResponsiveUtils.spacing(context, 4),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F2FF),
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 6)),
                          ),
                          child: Text(
                            '입고대기 ${items.length}건',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 품목 리스트 (확장 시)
                if (isExpanded)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFE0E0E0).withOpacity(0.5),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, itemIndex) {
                        final item = items[itemIndex];
                        final numberFormat = NumberFormat('#,###');

                        return Container(
                          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${itemIndex + 1}. ${item['item_name']}',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (item['specification'] != null)
                                      Text(
                                        '규격: ${item['specification']}',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 11,
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                    SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                                    Row(
                                      children: [
                                        Text(
                                          '수량: ${item['quantity']}',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 11,
                                            color: const Color(0xFF666666),
                                          ),
                                        ),
                                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                                        Text(
                                          '단가: ${numberFormat.format(item['unit_price_value'])}원',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 11,
                                            color: const Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '금액: ${numberFormat.format(item['amount_value'])}원',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canComplete) ...[
                                SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                                ElevatedButton(
                                  onPressed: () => _completeReceivingForItem(orderNumber, item['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: ResponsiveUtils.spacing(context, 12),
                                      vertical: ResponsiveUtils.spacing(context, 6),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                                    ),
                                  ),
                                  child: Text(
                                    '입고완료',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}