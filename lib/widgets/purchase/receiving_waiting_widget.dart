import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/user_role_helper.dart';
import '../../services/inquiry_service.dart';
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
  Map<String, List<Map<String, dynamic>>> _filteredItemsByOrder = {}; // 검색 필터링된 데이터
  final Map<String, bool> _expandedOrders = {};
  Map<String, Map<String, int>> _progressData = {}; // 진행률 데이터 저장
  bool _isLoading = false;
  
  // 검색 관련 변수
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReceivingItems();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // 검색어 변경 시 호출
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _filterItems();
    });
  }

  // 검색 필터링 로직
  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItemsByOrder = Map.from(_itemsByOrder);
      return;
    }

    final filteredItems = <String, List<Map<String, dynamic>>>{};
    final numberFormat = NumberFormat('#,###');

    for (final entry in _itemsByOrder.entries) {
      final orderNumber = entry.key;
      final items = entry.value;
      final firstItem = items.first;

      // 발주번호 검색
      final orderMatches = orderNumber.toLowerCase().contains(_searchQuery);
      
      // 업체명 검색
      final vendorMatches = (firstItem['vendor_name'] ?? '').toString().toLowerCase().contains(_searchQuery);
      
      // 요청자명 검색
      final requesterMatches = (firstItem['requester_name'] ?? '').toString().toLowerCase().contains(_searchQuery);

      // 품목별 검색
      final matchingItems = <Map<String, dynamic>>[];
      for (final item in items) {
        final itemNameMatches = (item['item_name'] ?? '').toString().toLowerCase().contains(_searchQuery);
        final specificationMatches = (item['specification'] ?? '').toString().toLowerCase().contains(_searchQuery);
        final quantityMatches = (item['quantity'] ?? '').toString().toLowerCase().contains(_searchQuery);
        
        // 금액 검색 (숫자와 포맷된 문자열 모두 지원)
        final unitPrice = item['unit_price_value'] ?? 0;
        final amount = item['amount_value'] ?? 0;
        final unitPriceStr = numberFormat.format(unitPrice);
        final amountStr = numberFormat.format(amount);
        
        final unitPriceMatches = unitPrice.toString().contains(_searchQuery) || 
                                unitPriceStr.contains(_searchQuery);
        final amountMatches = amount.toString().contains(_searchQuery) || 
                             amountStr.contains(_searchQuery);

        // 품목이 검색어와 일치하면 포함
        if (itemNameMatches || specificationMatches || quantityMatches || 
            unitPriceMatches || amountMatches) {
          matchingItems.add(item);
        }
      }

      // 발주번호, 업체명, 요청자명이 일치하거나 품목이 일치하면 포함
      if (orderMatches || vendorMatches || requesterMatches || matchingItems.isNotEmpty) {
        // 헤더 정보가 일치하면 모든 품목 포함, 아니면 일치하는 품목만 포함
        if (orderMatches || vendorMatches || requesterMatches) {
          filteredItems[orderNumber] = items;
        } else {
          filteredItems[orderNumber] = matchingItems;
        }
      }
    }

    _filteredItemsByOrder = filteredItems;
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
      final isRawMaterialManager = UserRoleHelper.isRawMaterialManager(purchaseRoles);
      final isConsumableManager = UserRoleHelper.isConsumableManager(purchaseRoles);
      final isCeo = purchaseRoles.contains('ceo');
      
      // 권한별 필터:
      // - app_admin: 전체 보기
      // - final_approver + raw_material_manager: '발주' 카테고리만
      // - final_approver + consumable_manager: '구매 요청' 카테고리만
      // - final_approver (세부권한 없음): 전체 보기
      // - middle_manager, ceo: 전체 보기
      // - lead buyer: 본인 요청 건만
      // - 그 외: 본인 요청 건만
      final hasFullAccess = isAppAdmin || isMiddleManager || isCeo || 
                           (isFinalApprover && !isRawMaterialManager && !isConsumableManager);
      
      // 입고대기: 미입고 AND (선진행 OR 최종승인) AND 아직 입고완료되지 않은 항목들만
      var query = _supabase
          .from('purchase_requests')
          .select('*, purchase_request_items(*)')
          .eq('is_received', false);  // 헤더 레벨에서 미입고만

      // 권한에 따른 필터링
      if (isFinalApprover && isRawMaterialManager && !isConsumableManager) {
        // final_approver + raw_material_manager: '발주' 카테고리만
        query = query.eq('payment_category', '발주');
      } else if (isFinalApprover && isConsumableManager && !isRawMaterialManager) {
        // final_approver + consumable_manager: '구매 요청' 카테고리만
        query = query.eq('payment_category', '구매 요청');
      } else if (!hasFullAccess) {
        // lead buyer 또는 일반 직원: 본인 것만 조회
        query = query.eq('requester_name', userName);
      }

      final response = await query;

      // response is always List<dynamic>, never null from Supabase
      final allPurchases = response as List<dynamic>;
      
      // progress_type 조건으로 필터링: 선진행 OR 최종승인
      final purchases = allPurchases.where((purchase) {
        final progressType = purchase['progress_type'] ?? '';
        final finalStatus = purchase['final_manager_status'] ?? '';
        final isHeaderReceived = purchase['is_received'] == true;
        
        // 이미 입고완료된 것은 제외
        if (isHeaderReceived) return false;
        
        // 선진행은 무조건 포함
        if (progressType.toString().contains('선진행')) return true;
        // 최종승인 완료된 것 포함
        if (finalStatus == 'approved') return true;
        
        return false;
      }).toList();
      
      // 추가 필터링: 실제로 미입고 품목이 있는 것만 표시
      final validPurchases = purchases.where((purchase) {
        final items = purchase['purchase_request_items'] as List<dynamic>? ?? [];
        // 미입고 품목이 하나라도 있는지 확인
        return items.any((item) => item['is_received'] != true);
      }).toList();
        Map<String, List<Map<String, dynamic>>> groupedItems = {};
        Map<String, Map<String, int>> progressData = {};

        for (var purchase in validPurchases) {
          final orderNumber = purchase['purchase_order_number'] as String;
          final items = purchase['purchase_request_items'] as List<dynamic>;
          
          // 전체 아이템 수
          final totalItems = items.length;
          
          // 미입고 아이템과 완료된 아이템 구분
          final unreceived = items.where((item) => 
            item['is_received'] == false
          ).toList();
          
          // 완료된 아이템 수 계산
          final completedItems = totalItems - unreceived.length;
          
          // 모든 아이템을 카드에 표시 (완료된 것도 히스토리로 보여주기 위해)
          // 모든 아이템 (완료된 것 + 미완료된 것) 포함하여 상세내역에 표시
          groupedItems[orderNumber] = items.map<Map<String, dynamic>>((item) => {
            ...Map<String, dynamic>.from(item as Map),
            'vendor_name': purchase['vendor_name'],
            'requester_name': purchase['requester_name'],
            'request_date': purchase['request_date'],
            'purchase_id': purchase['id'],
          }).toList();
          
          // 진행률 데이터 저장
          progressData[orderNumber] = {
            'total': totalItems,
            'completed': completedItems,
            'remaining': unreceived.length,
          };
        }

        setState(() {
          _itemsByOrder = groupedItems;
          _progressData = progressData;
          _isLoading = false;
          _filterItems(); // 데이터 로드 후 검색 필터 적용
        });
    } catch (e) {
      // 에러 로깅 제거됨 (Production 코드)
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 전체 입고완료 처리
  Future<void> _completeAllReceiving(List<Map<String, dynamic>> items) async {
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
        if (items.isNotEmpty && items.first['requester_name'] == userName) {
          canComplete = true;
        }
      }

      if (!canComplete) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('입고 완료 권한이 없습니다')),
          );
        }
        return;
      }

      // 미완료 품목만 필터링
      final unreceivedItems = items.where((item) => item['is_received'] != true).toList();
      if (unreceivedItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 모든 품목이 입고완료되었습니다')),
          );
        }
        return;
      }

      // 각 품목별로 입고완료 처리
      for (var item in unreceivedItems) {
        await _supabase
            .from('purchase_request_items')
            .update({
              'is_received': true,
              'received_at': DateTime.now().toIso8601String(),
            })
            .eq('id', item['id']);
      }

      // 해당 발주번호의 모든 품목이 입고완료되었는지 확인
      final orderNumber = items.first['purchase_order_number'] ?? items.first['id'].toString();
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
          SnackBar(content: Text('${unreceivedItems.length}건의 품목이 입고완료 처리되었습니다')),
        );
      }

      // 데이터 새로고침
      await _loadReceivingItems();

    } catch (e) {
      // 에러 발생 시 UI 상태 되돌리기
      await _loadReceivingItems();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전체 입고완료 처리 중 오류가 발생했습니다')),
        );
      }
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

    // 검색창과 리스트를 포함하는 컬럼
    return Column(
      children: [
        // 검색창 (컴팩트 디자인)
        Container(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
          child: SizedBox(
            height: ResponsiveUtils.spacing(context, 36),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '발주번호, 업체명, 요청자, 품목명, 규격, 수량, 금액 검색...',
                hintStyle: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 12,
                  color: const Color(0xFF8E8E93),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: const Color(0xFF8E8E93),
                  size: ResponsiveUtils.iconSize(context, 18),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear, 
                          color: const Color(0xFF8E8E93),
                          size: ResponsiveUtils.iconSize(context, 18),
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 12),
                  vertical: ResponsiveUtils.spacing(context, 6),
                ),
                isDense: true,
              ),
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 13,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
        ),
        // 검색 결과 표시
        if (_searchQuery.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacing(context, 16)),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: ResponsiveUtils.iconSize(context, 16),
                  color: const Color(0xFF8E8E93),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                Text(
                  '검색결과: ${_filteredItemsByOrder.length}건',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        // 리스트 영역
        Expanded(
          child: _buildListContent(),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    final itemsToShow = _filteredItemsByOrder;

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

    if (itemsToShow.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: ResponsiveUtils.iconSize(context, 80),
              color: const Color(0xFFE0E0E0),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 20)),
            Text(
              '검색 결과가 없습니다',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
            Text(
              '다른 검색어를 시도해보세요',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 14,
                color: const Color(0xFF8E8E93),
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
        itemCount: itemsToShow.length,
        itemBuilder: (context, index) {
          final orderNumber = itemsToShow.keys.elementAt(index);
          final items = itemsToShow[orderNumber]!;
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
            margin: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
              border: Border.all(
                color: isExpanded ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
                width: isExpanded ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isExpanded 
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : const Color(0xFF000000).withValues(alpha: 0.03),
                  blurRadius: isExpanded ? 12 : 6,
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
                    top: Radius.circular(ResponsiveUtils.spacing(context, 12)),
                    bottom: isExpanded ? Radius.zero : Radius.circular(ResponsiveUtils.spacing(context, 12)),
                  ),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveUtils.spacing(context, 20),
                      ResponsiveUtils.spacing(context, 20),
                      ResponsiveUtils.spacing(context, 20),
                      ResponsiveUtils.spacing(context, 8),
                    ),
                    decoration: BoxDecoration(
                      color: isExpanded ? const Color(0xFFF8FAFC) : Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(ResponsiveUtils.spacing(context, 12)),
                        bottom: isExpanded ? Radius.zero : Radius.circular(ResponsiveUtils.spacing(context, 12)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 좌측 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 발주번호와 카테고리
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        color: AppColors.primary,
                                        size: ResponsiveUtils.iconSize(context, 20),
                                      ),
                                      SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                      Expanded(
                                        child: Text(
                                          orderNumber,
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                  // 업체명
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        color: const Color(0xFF8E8E93),
                                        size: ResponsiveUtils.iconSize(context, 16),
                                      ),
                                      SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                      Expanded(
                                        child: Text(
                                          firstItem['vendor_name'] ?? '업체명 없음',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF4B5563),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // 수정요청 버튼 (요청자 본인만 표시)
                            _buildEditRequestButton(context, orderNumber, firstItem),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                        // 요청자와 입고요청일 정보
                        Row(
                          children: [
                            // 요청자 정보
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: const Color(0xFF8E8E93),
                                    size: ResponsiveUtils.iconSize(context, 16),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                  Flexible(
                                    child: Text(
                                      firstItem['requester_name'] ?? '요청자 없음',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF4B5563),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                            // 입고요청일 정보
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    color: const Color(0xFF8E8E93),
                                    size: ResponsiveUtils.iconSize(context, 16),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '입고요청일',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                        Text(
                                          dateFormat.format(DateTime.parse(firstItem['request_date'])),
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
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
                        SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                        // 진행률 바와 퍼센트 표시
                        _buildProgressSection(items),
                        SizedBox(height: ResponsiveUtils.spacing(context, 2)),
                        // 하단 꺽쇠 아이콘 (컴팩하게)
                        Center(
                          child: Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: const Color(0xFF8E8E93),
                            size: ResponsiveUtils.iconSize(context, 20),
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
                          color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
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
                        final isReceived = item['is_received'] == true;

                        return Container(
                          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                          decoration: BoxDecoration(
                            color: isReceived ? const Color(0xFFF0F9FF) : Colors.transparent,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 완료 상태 표시
                              Container(
                                margin: EdgeInsets.only(right: ResponsiveUtils.spacing(context, 12)),
                                width: ResponsiveUtils.spacing(context, 20),
                                height: ResponsiveUtils.spacing(context, 20),
                                decoration: BoxDecoration(
                                  color: isReceived ? AppColors.primary : const Color(0xFFE0E0E0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${itemIndex + 1}. ${item['item_name']}',
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isReceived ? const Color(0xFF8E8E93) : const Color(0xFF1C1C1E),
                                            ).copyWith(
                                              decoration: isReceived ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                        if (isReceived)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: ResponsiveUtils.spacing(context, 6),
                                              vertical: ResponsiveUtils.spacing(context, 2),
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                                              border: Border.all(
                                                color: AppColors.primary.withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '완료됨',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (item['specification'] != null)
                                      Text(
                                        '규격: ${item['specification']}',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 14,
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
                                            fontSize: 13,
                                            color: const Color(0xFF666666),
                                          ),
                                        ),
                                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                                        Text(
                                          '단가: ${numberFormat.format(item['unit_price_value'])}원',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 13,
                                            color: const Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '금액: ${numberFormat.format(item['amount_value'])}원',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canComplete && !isReceived) ...[
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
                                      fontSize: 12,
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

  Widget _buildProgressSection(List<Map<String, dynamic>> items) {
    final receivedItems = items.where((item) => item['is_received'] == true).length;
    final totalItems = items.length;
    final pendingItems = totalItems - receivedItems;
    final percentage = totalItems > 0 ? (receivedItems / totalItems * 100).round() : 0;

    return Column(
      children: [
        // 진행률 바와 정보
        Container(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // 상단 정보
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.primary,
                        size: ResponsiveUtils.iconSize(context, 18),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '입고 진행률',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${percentage}% (${receivedItems}/${totalItems})',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 12)),
              // 진행률 바
              Container(
                height: ResponsiveUtils.spacing(context, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBBDEFB),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 4)),
                ),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 4)),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 12)),
              // 하단 상세 정보
              Row(
                children: [
                  // 대기 중
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: ResponsiveUtils.spacing(context, 8),
                          height: ResponsiveUtils.spacing(context, 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFBBDEFB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                        Text(
                          '대기: ${pendingItems}건',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 완료
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: ResponsiveUtils.spacing(context, 8),
                          height: ResponsiveUtils.spacing(context, 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                        Text(
                          '완료: ${receivedItems}건',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 6)),
        // 전체입고완료 버튼
        _buildCompleteAllButton(items),
      ],
    );
  }

  // 전체입고완료 버튼 빌드
  Widget _buildCompleteAllButton(List<Map<String, dynamic>> items) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];
    final currentUserName = employee?['name'] as String? ?? '';
    
    // 권한 체크: app_admin, lead_buyer, 또는 본인 요청한 것만 전체완료 가능
    final canComplete = UserRoleHelper.isAppAdmin(purchaseRoles) || 
                       UserRoleHelper.isPureLeadBuyer(purchaseRoles) ||
                       (items.isNotEmpty && items.first['requester_name'] == currentUserName);
    
    // 완료되지 않은 품목이 있는지 확인
    final pendingItems = items.where((item) => item['is_received'] != true).toList();
    final receivedItems = items.where((item) => item['is_received'] == true).length;
    final totalItems = items.length;
    final percentage = totalItems > 0 ? (receivedItems / totalItems * 100).round() : 0;

    return Row(
      children: [
        // 진행률 정보
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFF8E8E93),
                size: ResponsiveUtils.iconSize(context, 16),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 6)),
              Text(
                percentage == 100 ? '모든 품목이 입고완료되었습니다' : '미완료 품목: ${pendingItems.length}건',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 12,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
        // 전체입고완료 버튼
        if (canComplete && percentage < 100)
          ElevatedButton(
            onPressed: () => _completeAllReceiving(items),
            child: Text(
              '전체입고완료',
              style: ResponsiveUtils.getTextStyle(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacing(context, 16),
                vertical: ResponsiveUtils.spacing(context, 8),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              ),
            ),
          ),
      ],
    );
  }

  // 수정요청 버튼 빌드 (요청자 본인만 표시)
  Widget _buildEditRequestButton(BuildContext context, String orderNumber, Map<String, dynamic> firstItem) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final currentUserName = employee?['name'] as String? ?? '';
    final requesterName = firstItem['requester_name'] as String? ?? '';
    
    // 본인이 요청한 발주만 수정요청 가능
    if (currentUserName != requesterName) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: EdgeInsets.only(left: ResponsiveUtils.spacing(context, 8)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEditRequestDialog(context, orderNumber, firstItem),
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 12),
              vertical: ResponsiveUtils.spacing(context, 6),
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: ResponsiveUtils.iconSize(context, 16),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                Text(
                  '수정요청',
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
        ),
      ),
    );
  }

  // 수정요청 다이얼로그 표시
  Future<void> _showEditRequestDialog(BuildContext context, String orderNumber, Map<String, dynamic> firstItem) async {
    final TextEditingController contentController = TextEditingController();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final userName = employee?['name'] as String? ?? '';
    final userEmail = employee?['email'] as String? ?? '';
    final vendorName = firstItem['vendor_name'] as String? ?? '업체명 없음';
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 16)),
          ),
          title: Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ResponsiveUtils.spacing(context, 16)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_document,
                  color: Colors.white,
                  size: ResponsiveUtils.iconSize(context, 24),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                Expanded(
                  child: Text(
                    '발주 수정요청',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 발주 정보 표시
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            color: AppColors.primary,
                            size: ResponsiveUtils.iconSize(context, 18),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                          Text(
                            '발주번호: $orderNumber',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: const Color(0xFF64748B),
                            size: ResponsiveUtils.iconSize(context, 18),
                          ),
                          SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                          Text(
                            '업체명: $vendorName',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                // 수정요청 내용 입력
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      color: AppColors.primary,
                      size: ResponsiveUtils.iconSize(context, 20),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    Text(
                      '수정요청 내용 *',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '예: 품목 변경, 수량 조정, 배송지 변경 등\n상세한 수정 내용을 입력해주세요.',
                    hintStyle: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                Text(
                  '필수 입력 항목입니다.',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final content = contentController.text.trim();
                if (content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('수정요청 내용을 입력해주세요.'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 20),
                  vertical: ResponsiveUtils.spacing(context, 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                ),
              ),
              child: Text(
                '요청 전송',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
    
    // 사용자가 전송을 눌렀을 때만 수정요청 등록
    if (result == true && contentController.text.trim().isNotEmpty) {
      await _submitEditRequest(
        orderNumber: orderNumber,
        vendorName: vendorName,
        content: contentController.text.trim(),
        userName: userName,
        userEmail: userEmail,
      );
    }
  }
  
  // 수정요청 등록 처리
  Future<void> _submitEditRequest({
    required String orderNumber,
    required String vendorName,
    required String content,
    required String userName,
    required String userEmail,
  }) async {
    try {
      // 로딩 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정요청을 등록 중입니다...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      final inquiryService = InquiryService();
      final result = await inquiryService.createInquiry(
        inquiryType: '기타',  // DB에서 'modify'로 매핑됨
        subject: '[발주 수정요청] $orderNumber - $vendorName',
        message: content,
        userName: userName,
        userEmail: userEmail,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '수정요청이 성공적으로 등록되었습니다.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '수정요청 등록에 실패했습니다.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정요청 등록 중 오류가 발생했습니다.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}