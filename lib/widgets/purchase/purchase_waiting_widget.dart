import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/user_role_helper.dart';
import 'package:intl/intl.dart';

// 구매대기 위젯
class PurchaseWaitingWidget extends StatefulWidget {
  const PurchaseWaitingWidget({super.key});

  @override
  State<PurchaseWaitingWidget> createState() => _PurchaseWaitingWidgetState();
}

class _PurchaseWaitingWidgetState extends State<PurchaseWaitingWidget> {
  final _supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> _itemsByOrder = {};
  Map<String, List<Map<String, dynamic>>> _filteredItemsByOrder = {};
  final Map<String, bool> _expandedOrders = {};
  bool _isLoading = false;
  
  // 검색 관련
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadPurchaseItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _filterItems();
    });
  }

  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItemsByOrder = Map.from(_itemsByOrder);
      return;
    }

    Map<String, List<Map<String, dynamic>>> filteredItems = {};
    final numberFormat = NumberFormat('#,###');

    for (var entry in _itemsByOrder.entries) {
      final orderNumber = entry.key;
      final items = entry.value;
      final firstItem = items.first;

      // 헤더 정보 검색
      final orderMatches = orderNumber.toLowerCase().contains(_searchQuery);
      final vendorMatches = (firstItem['vendor_name'] ?? '').toString().toLowerCase().contains(_searchQuery);
      final requesterMatches = (firstItem['requester_name'] ?? '').toString().toLowerCase().contains(_searchQuery);

      // 품목별 검색
      List<Map<String, dynamic>> matchingItems = [];
      for (var item in items) {
        final itemNameMatches = (item['item_name'] ?? '').toString().toLowerCase().contains(_searchQuery);
        final specificationMatches = (item['specification'] ?? '').toString().toLowerCase().contains(_searchQuery);
        final quantityMatches = (item['quantity'] ?? '').toString().toLowerCase().contains(_searchQuery);

        // 숫자 검색 (금액)
        final unitPrice = item['unit_price_value'] ?? 0;
        final amount = item['amount_value'] ?? 0;
        final unitPriceStr = numberFormat.format(unitPrice);
        final amountStr = numberFormat.format(amount);

        final unitPriceMatches = unitPrice.toString().contains(_searchQuery) || 
                                unitPriceStr.contains(_searchQuery);
        final amountMatches = amount.toString().contains(_searchQuery) || 
                             amountStr.contains(_searchQuery);

        if (itemNameMatches || specificationMatches || quantityMatches || 
            unitPriceMatches || amountMatches) {
          matchingItems.add(item);
        }
      }

      // 헤더가 매치되면 모든 아이템 포함, 아니면 매치된 아이템만
      if (orderMatches || vendorMatches || requesterMatches) {
        filteredItems[orderNumber] = items;
      } else if (matchingItems.isNotEmpty) {
        filteredItems[orderNumber] = matchingItems;
      }
    }

    setState(() {
      _filteredItemsByOrder = filteredItems;
    });
  }

  Future<void> _loadPurchaseItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employee = userProvider.employee;
      final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];
      final userName = employee?['name'] as String? ?? '';
      
      // UserRoleHelper 사용하여 권한 체크
      final isAppAdmin = UserRoleHelper.isAppAdmin(purchaseRoles);
      final isLeadBuyer = UserRoleHelper.isLeadBuyer(purchaseRoles);
      final isFinalApprover = UserRoleHelper.isFinalApprover(purchaseRoles);
      final isConsumableManager = UserRoleHelper.isConsumableManager(purchaseRoles);

      // 구매현황 조회 권한이 있는 경우만 접근 가능
      if (!UserRoleHelper.canViewPurchaseStatus(purchaseRoles)) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 구매대기: 미구매 AND 구매 요청 카테고리의 항목들만 조회 (입고대기와 동일한 로직)
      // progress_type 조건: 선진행은 무조건, 일반은 승인완료된 것만
      var query = _supabase
          .from('purchase_requests')
          .select('*, purchase_request_items(*)')
          .eq('payment_category', '구매 요청')  // 구매대기는 '구매 요청' 카테고리만
          .eq('is_payment_completed', false);  // 헤더 레벨에서 미구매만

      // 권한에 따른 필터링
      // final_approver + raw_material_manager는 구매대기 탭에서 데이터 없음 (발주만 관리)
      // final_approver + consumable_manager는 '구매 요청' 카테고리 조회 가능
      // lead buyer, app_admin은 모든 구매 요청 조회 가능
      if (!isAppAdmin && !isLeadBuyer && !(isFinalApprover && isConsumableManager)) {
        // 일반 직원: 본인 것만 조회
        query = query.eq('requester_name', userName);
      }

      final response = await query;

      // response is always List<dynamic>, never null from Supabase
        final allPurchases = response as List<dynamic>;
        
        // progress_type 조건으로 필터링 (웹앱과 동일)
        final purchases = allPurchases.where((purchase) {
          final progressType = purchase['progress_type'] ?? '';
          final finalStatus = purchase['final_manager_status'] ?? '';
          
          // 선진행은 무조건 포함 (승인 상태 무관)
          if (progressType.toString().contains('선진행')) return true;
          // 일반은 최종승인 완료된 것만
          if (progressType.toString().contains('일반') && finalStatus == 'approved') return true;
          
          return false;
        }).toList();
        
        // 추가 필터링: 실제로 미구매 품목이 있는 것만 표시 (입고대기와 동일한 로직)
        final validPurchases = purchases.where((purchase) {
          final items = purchase['purchase_request_items'] as List<dynamic>? ?? [];
          // 미구매 품목이 하나라도 있는지 확인
          return items.any((item) => item['is_payment_completed'] != true);
        }).toList();
        
        Map<String, List<Map<String, dynamic>>> groupedItems = {};

        for (var purchase in validPurchases) {
          final orderNumber = purchase['purchase_order_number'] as String;
          final items = purchase['purchase_request_items'] as List<dynamic>? ?? [];
          
          // 모든 품목 포함 (완료된 것도 히스토리로 보여주기 위해)
          // 완료된 아이템과 미완료 아이템 모두 표시
          if (items.isNotEmpty) {
            groupedItems[orderNumber] = items.map<Map<String, dynamic>>((item) => {
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
          _filterItems(); // 검색 필터 적용
        });
    } catch (e) {
      // 에러 로깅 제거됨 (Production 코드)
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 진행률 섹션 빌드
  Widget _buildProgressSection(List<Map<String, dynamic>> items) {
    final completedItems = items.where((item) => item['is_payment_completed'] == true).length;
    final totalItems = items.length;
    final pendingItems = totalItems - completedItems;
    final percentage = totalItems > 0 ? (completedItems / totalItems * 100).round() : 0;

    return Column(
      children: [
        // 진행률 바와 정보
        Container(
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E6),
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
            border: Border.all(
              color: const Color(0xFFFF9500).withValues(alpha: 0.3),
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
                        Icons.shopping_cart_outlined,
                        color: const Color(0xFFFF9500),
                        size: ResponsiveUtils.iconSize(context, 18),
                      ),
                      SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                      Text(
                        '구매 진행률',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF9500),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${percentage}% (${completedItems}/${totalItems})',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF9500),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 12)),
              // 진행률 바
              Container(
                height: ResponsiveUtils.spacing(context, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4B5),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 4)),
                ),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF9500)),
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
                            color: Color(0xFFFFE4B5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                        Text(
                          '대기: ${pendingItems}건',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: const Color(0xFF8B5A2B),
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9500),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                        Text(
                          '완료: ${completedItems}건',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 12,
                            color: const Color(0xFF8B5A2B),
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
        // 전체구매완료 버튼
        _buildCompleteAllButton(items),
      ],
    );
  }

  // 전체구매완료 버튼 빌드
  Widget _buildCompleteAllButton(List<Map<String, dynamic>> items) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];
    final currentUserName = employee?['name'] as String? ?? '';
    
    // 권한 체크: app_admin, lead_buyer, 또는 본인 요청한 것만 전체완료 가능
    final canComplete = UserRoleHelper.isAppAdmin(purchaseRoles) || 
                       UserRoleHelper.isLeadBuyer(purchaseRoles) ||
                       (items.isNotEmpty && items.first['requester_name'] == currentUserName);
    
    // 완료되지 않은 품목이 있는지 확인
    final pendingItems = items.where((item) => item['is_payment_completed'] != true).toList();
    final completedItems = items.where((item) => item['is_payment_completed'] == true).length;
    final totalItems = items.length;
    final percentage = totalItems > 0 ? (completedItems / totalItems * 100).round() : 0;

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
                percentage == 100 ? '모든 품목이 구매완료되었습니다' : '미완료 품목: ${pendingItems.length}건',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 12,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
        // 전체구매완료 버튼
        if (canComplete && percentage < 100)
          ElevatedButton(
            onPressed: () => _completeAllPayment(items),
            child: Text(
              '전체구매완료',
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

  // 전체구매완료 처리
  Future<void> _completeAllPayment(List<Map<String, dynamic>> items) async {
    try {
      // 완료되지 않은 품목들만 필터링
      final pendingItems = items.where((item) => item['is_payment_completed'] != true).toList();
      
      if (pendingItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 모든 품목이 구매완료되었습니다')),
          );
        }
        return;
      }

      // 각 품목별로 구매완료 처리
      for (var item in pendingItems) {
        await _supabase
            .from('purchase_request_items')
            .update({
              'is_payment_completed': true,
              'payment_completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', item['id']);
      }

      // 해당 발주번호의 모든 품목이 구매완료되었는지 확인
      final orderNumber = items.first['purchase_order_number'] ?? items.first['id'].toString();
      final remainingItems = await _supabase
          .from('purchase_request_items')
          .select()
          .eq('purchase_order_number', orderNumber)
          .eq('is_payment_completed', false);

      // 모든 품목이 구매완료되면 헤더도 업데이트
      if (remainingItems.isEmpty) {
        await _supabase
            .from('purchase_requests')
            .update({
              'is_payment_completed': true,
              'payment_completed_at': DateTime.now().toIso8601String(),
              'progress_type': '구매 완료',
            })
            .eq('purchase_order_number', orderNumber);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pendingItems.length}건의 품목이 구매완료 처리되었습니다')),
        );
      }

      // 데이터 새로고침
      await _loadPurchaseItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전체구매완료 처리 중 오류가 발생했습니다')),
        );
      }
    }
  }

  // 품목별 구매완료 처리
  Future<void> _completePaymentForItem(String orderNumber, int itemId) async {
    try {
      // purchase_request_items 테이블의 특정 품목 업데이트
      await _supabase
          .from('purchase_request_items')
          .update({
            'is_payment_completed': true,
            'payment_completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId);

      // 해당 발주번호의 모든 품목이 구매완료되었는지 확인
      final remainingItems = await _supabase
          .from('purchase_request_items')
          .select()
          .eq('purchase_order_number', orderNumber)
          .eq('is_payment_completed', false);

      // 모든 품목이 구매완료되면 헤더도 업데이트
      if (remainingItems.isEmpty) {
        await _supabase
            .from('purchase_requests')
            .update({
              'is_payment_completed': true,
              'payment_completed_at': DateTime.now().toIso8601String(),
              'progress_type': '구매 완료',
            })
            .eq('purchase_order_number', orderNumber);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매 완료 처리되었습니다')),
        );
      }

      // 데이터 새로고침
      await _loadPurchaseItems();
    } catch (e) {
      // 에러 로깅 제거됨 (Production 코드)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매완료 처리 중 오류가 발생했습니다')),
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
      return RefreshIndicator(
        onRefresh: _loadPurchaseItems,
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
                    Icons.shopping_cart_outlined,
                    size: ResponsiveUtils.iconSize(context, 80),
                    color: const Color(0xFFE0E0E0),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                  Text(
                    '구매대기 항목이 없습니다',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (itemsToShow.isEmpty && _searchQuery.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPurchaseItems,
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
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPurchaseItems,
      child: ListView.builder(
        padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
        itemCount: itemsToShow.length,
        itemBuilder: (context, index) {
          final orderNumber = itemsToShow.keys.elementAt(index);
          final items = itemsToShow[orderNumber]!;
          final isExpanded = _expandedOrders[orderNumber] ?? false;
          final firstItem = items.first;
          final dateFormat = DateFormat('yyyy-MM-dd');

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
                                        Icons.shopping_cart,
                                        color: const Color(0xFFFF9500),
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
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                        // 요청자와 날짜 정보
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: const Color(0xFF8E8E93),
                              size: ResponsiveUtils.iconSize(context, 16),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                            Text(
                              firstItem['requester_name'] ?? '요청자 없음',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 16)),
                            Icon(
                              Icons.calendar_today_outlined,
                              color: const Color(0xFF8E8E93),
                              size: ResponsiveUtils.iconSize(context, 16),
                            ),
                            SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                            Text(
                              dateFormat.format(DateTime.parse(firstItem['request_date'])),
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                        // 진행률 표시
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

                        final isCompleted = item['is_payment_completed'] == true;
                        
                        return Container(
                          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFF0F9FF) : Colors.transparent,
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
                                  color: isCompleted ? const Color(0xFFFF9500) : const Color(0xFFE0E0E0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${itemIndex + 1}. ${item['item_name']}',
                                      style: ResponsiveUtils.getTextStyle(
                                        context,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isCompleted ? const Color(0xFF666666) : const Color(0xFF1C1C1E),
                                      ).copyWith(
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (item['specification'] != null)
                                      Text(
                                        '규격: ${item['specification']}',
                                        style: ResponsiveUtils.getTextStyle(
                                          context,
                                          fontSize: 14,
                                          color: isCompleted ? const Color(0xFF999999) : const Color(0xFF666666),
                                        ).copyWith(
                                          decoration: isCompleted ? TextDecoration.lineThrough : null,
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
                                            color: isCompleted ? const Color(0xFF999999) : const Color(0xFF666666),
                                          ).copyWith(
                                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                                        Text(
                                          '단가: ${numberFormat.format(item['unit_price_value'])}원',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 13,
                                            color: isCompleted ? const Color(0xFF999999) : const Color(0xFF666666),
                                          ).copyWith(
                                            decoration: isCompleted ? TextDecoration.lineThrough : null,
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
                                        color: isCompleted ? const Color(0xFF999999) : const Color(0xFFFF9500),
                                      ).copyWith(
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                              // 구매완료 버튼 (완료되지 않은 경우만)
                              if (!isCompleted)
                                ElevatedButton(
                                  onPressed: () => _completePaymentForItem(orderNumber, item['id']),
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
                                    '구매완료',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                // 완료 배지
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveUtils.spacing(context, 12),
                                    vertical: ResponsiveUtils.spacing(context, 8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                                    border: Border.all(
                                      color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '완료됨',
                                    style: ResponsiveUtils.getTextStyle(
                                      context,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFF9500),
                                    ),
                                  ),
                                ),
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