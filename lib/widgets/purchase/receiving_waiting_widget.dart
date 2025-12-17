import 'dart:convert';

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
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // mounted 체크를 포함한 안전한 setState 래퍼
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }
  
  // 검색 관련 변수
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // 부서-이름 필터 관련 변수
  List<String> _departments = [];
  List<String> _employees = [];
  Map<String, List<String>> _departmentEmployees = {}; // 부서별 직원 맵
  String? _selectedDepartment;
  String? _selectedEmployee;
  bool _isLoadingDepartments = false;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _searchController.addListener(_onSearchChanged);
  }

  // 품목 입고 입력 다이얼로그 (입고일/실입고수량/비고)
  Future<Map<String, dynamic>?> _showReceiveInputDialog(
    Map<String, dynamic> item, {
    DateTime? initialDate,
    int? initialQuantity,
  }) async {
    final requestedQty = (item['quantity'] ?? 0) as int;
    DateTime selectedDate = initialDate ?? DateTime.now();
    final qtyController = TextEditingController(
      text: (initialQuantity ?? 0).toString(),
    );
    final noteController = TextEditingController(
      text: item['delivery_notes']?.toString() ?? '',
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '입고 처리',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['item_name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '요청 수량 ${requestedQty}개',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 입고일 셀
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                      Text(
                        '실제 입고일',
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 14,
                              color: const Color(0xFF475467),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _dateFormat.format(selectedDate),
                            style: ResponsiveUtils.getTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 수량 필드 + 동일 버튼
                  Row(
                    children: [
                      Text(
                        '실입고 수량',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 14,
                          color: const Color(0xFF475467),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed: () {
                          qtyController.text = requestedQty.toString();
                          setState(() {});
                        },
                        child: const Text('요청수량과 동일'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '실입고 수량',
                      helperText: '요청 수량: $requestedQty',
                      helperStyle: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 비고 필드
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: '비고 (선택)',
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.2),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.end,
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    foregroundColor: const Color(0xFF6B7280),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('취소'),
                ),
                Builder(
                  builder: (context) {
                    final parsedQty = int.tryParse(qtyController.text.trim());
                    final isValid = parsedQty != null && parsedQty > 0;
                    return FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isValid ? AppColors.primary : const Color(0xFFD1D5DB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: isValid
                          ? () {
                              Navigator.of(context).pop({
                                'quantity': parsedQty,
                                'date': selectedDate,
                                'note': noteController.text.trim(),
                              });
                            }
                          : null,
                      child: const Text('확인'),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
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

  // 필터 초기화
  Future<void> _initializeFilters() async {
    await _loadDepartments();
    if (!mounted) return;
    await _setDefaultFilters();
    if (!mounted) return;
    await _loadReceivingItems();
  }

  // 부서 목록과 부서별 직원 목록을 한번에 로드
  Future<void> _loadDepartments() async {
    _safeSetState(() => _isLoadingDepartments = true);
    
    try {
      // 모든 직원의 부서와 이름을 한번에 가져오기
      final response = await _supabase
          .from('employees')
          .select('department, name')
          .not('department', 'is', null)
          .not('name', 'is', null);
      
      final Set<String> departmentSet = {};
      final Map<String, List<String>> departmentEmployeesMap = {};
      final List<String> allEmployees = [];
      
      for (final row in response as List<dynamic>) {
        final dept = row['department'] as String?;
        final name = row['name'] as String?;
        
        if (dept != null && name != null && dept.trim().isNotEmpty && name.trim().isNotEmpty) {
          final cleanDept = dept.trim();
          final cleanName = name.trim();
          
          departmentSet.add(cleanDept);
          allEmployees.add(cleanName);
          
          if (!departmentEmployeesMap.containsKey(cleanDept)) {
            departmentEmployeesMap[cleanDept] = [];
          }
          departmentEmployeesMap[cleanDept]!.add(cleanName);
        }
      }
      
      // 각 부서별 직원 목록 정렬
      for (final key in departmentEmployeesMap.keys) {
        departmentEmployeesMap[key]!.sort();
      }
      
      _safeSetState(() {
        _departments = ['전체', ...departmentSet.toList()..sort()];
        _departmentEmployees = departmentEmployeesMap;
        // 전체 직원 목록 (중복 제거 후 정렬)
        _employees = ['전체', ...allEmployees.toSet().toList()..sort()];
        _isLoadingDepartments = false;
      });
    } catch (e) {
      _safeSetState(() {
        _departments = ['전체'];
        _employees = ['전체'];
        _departmentEmployees = {};
        _isLoadingDepartments = false;
      });
    }
  }


  // 기본 필터값 설정 (현재 사용자의 부서-이름)
  Future<void> _setDefaultFilters() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employee = userProvider.employee;
      final userName = employee?['name'] as String? ?? '';
      final userDepartment = employee?['department'] as String? ?? '';
      final purchaseRoles = employee?['purchase_role'] as List<dynamic>? ?? [];
      
      // app_admin의 경우 기본값을 "전체"로 설정
      if (UserRoleHelper.isAppAdmin(purchaseRoles)) {
        _safeSetState(() {
          _selectedDepartment = '전체';
          _selectedEmployee = '전체';
        });
      } else if (userName.isNotEmpty && userDepartment.isNotEmpty) {
        _safeSetState(() {
          _selectedDepartment = userDepartment;
          _selectedEmployee = userName;
        });
      } else {
        // 기본값 설정 실패시 전체로 설정
        _safeSetState(() {
          _selectedDepartment = '전체';
          _selectedEmployee = '전체';
        });
      }
    } catch (e) {
      _safeSetState(() {
        _selectedDepartment = '전체';
        _selectedEmployee = '전체';
      });
    }
  }

  // 특정 부서 소속 직원 이름 목록 조회 (필터링용)
  Future<List<String>> _getDepartmentEmployees(String department) async {
    try {
      final response = await _supabase
          .from('employees')
          .select('name')
          .eq('department', department)
          .not('name', 'is', null);
      
      final List<String> employeeNames = [];
      for (final row in response as List<dynamic>) {
        final name = row['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          employeeNames.add(name.trim());
        }
      }
      
      return employeeNames;
    } catch (e) {
      return [];
    }
  }

  // 부서 선택 변경시 처리 (즉시 필터링, 로딩 없음)
  void _onDepartmentChanged(String? department) {
    if (department == null) return;
    
    setState(() {
      _selectedDepartment = department;
      // 부서에서 "전체"를 선택하면 이름도 자동으로 "전체"로 설정
      if (department == '전체') {
        _selectedEmployee = '전체';
        _employees = ['전체', ..._departmentEmployees.values.expand((e) => e).toSet().toList()..sort()];
      } else {
        _selectedEmployee = '전체'; // 부서 변경시 이름은 전체로 리셋
        // 선택된 부서의 직원 목록으로 업데이트
        final deptEmployees = _departmentEmployees[department] ?? [];
        _employees = ['전체', ...deptEmployees];
      }
    });
    
    // 데이터 다시 로드 (로딩 표시 없이)
    _loadReceivingItems();
  }

  // 직원 선택 변경시 처리 (즉시 필터링, 로딩 없음)
  void _onEmployeeChanged(String? employee) {
    if (employee == null) return;
    
    setState(() {
      _selectedEmployee = employee;
    });
    
    // 데이터 다시 로드 (로딩 표시 없이)
    _loadReceivingItems();
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
    _safeSetState(() {
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
      final isHr = UserRoleHelper.isHr(purchaseRoles);
      final isCeo = purchaseRoles.contains('ceo');
      
      // 권한별 필터:
      // - app_admin: 전체 보기
      // - final_approver + raw_material_manager: '발주' 카테고리만
      // - final_approver + consumable_manager: '구매 요청' 카테고리만
      // - final_approver (세부권한 없음): 전체 보기
      // - middle_manager, ceo, hr: 전체 보기
      // - lead buyer: 본인 요청 건만
      // - 그 외: 본인 요청 건만
      final hasFullAccess = isAppAdmin || isMiddleManager || isCeo || isHr ||
                           (isFinalApprover && !isRawMaterialManager && !isConsumableManager);
      
      // 입고대기: 미입고 AND (선진행 OR 최종승인) AND 아직 입고완료되지 않은 항목들만
      var query = _supabase
          .from('purchase_requests')
          .select('*, purchase_request_items(*)')
          .eq('is_received', false);  // 헤더 레벨에서 미입고만

      // 권한에 따른 카테고리 필터링 (기존 권한 시스템 유지)
      if (isFinalApprover && isRawMaterialManager && !isConsumableManager) {
        // final_approver + raw_material_manager: '발주' 카테고리만
        query = query.eq('payment_category', '발주');
      } else if (isFinalApprover && isConsumableManager && !isRawMaterialManager) {
        // final_approver + consumable_manager: '구매 요청' 카테고리만
        query = query.eq('payment_category', '구매 요청');
      }
      
      // 부서-이름 필터 적용 (모든 사용자에게 적용)
      if (_selectedEmployee != null && _selectedEmployee != '전체') {
        // 특정 직원 선택시 해당 직원 요청 건만
        query = query.eq('requester_name', _selectedEmployee!);
      } else if (_selectedDepartment != null && _selectedDepartment != '전체') {
        // 특정 부서 선택시 해당 부서 소속 직원들의 요청 건
        final deptEmployees = await _getDepartmentEmployees(_selectedDepartment!);
        if (deptEmployees.isNotEmpty) {
          query = query.inFilter('requester_name', deptEmployees);
        }
      }
      // 부서도 전체, 이름도 전체면 추가 필터링 없이 모든 데이터 조회

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
            'requester_id': purchase['requester_id'],
            'request_date': purchase['request_date'],
            'delivery_request_date': purchase['delivery_request_date'],
            'revised_delivery_request_date': purchase['revised_delivery_request_date'],
            'purchase_id': purchase['id'],
          }).toList();
          
          // 진행률 데이터 저장
          progressData[orderNumber] = {
            'total': totalItems,
            'completed': completedItems,
            'remaining': unreceived.length,
          };
        }

        _safeSetState(() {
          _itemsByOrder = groupedItems;
          _progressData = progressData;
          _isLoading = false;
          _filterItems(); // 데이터 로드 후 검색 필터 적용
        });
    } catch (e) {
      // 에러 로깅 제거됨 (Production 코드)
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  // 전체 입고완료 처리
  Future<void> _completeAllReceiving(List<Map<String, dynamic>> items) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employee = userProvider.employee;
      final currentUserId = employee?['id'];
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

      final DateTime? selectedDate = await _showReceiveDatePicker(
        context: context,
        initialDate: DateTime.now(),
      );
      if (selectedDate == null) return;

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
              'received_quantity': item['quantity'] ?? 0,
              'actual_received_date': selectedDate.toIso8601String(),
              'delivery_status': 'received',
              'received_at': DateTime.now().toIso8601String(),
              'received_by': currentUserId,
              'received_by_name': userName,
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
              'received_at': selectedDate.toIso8601String(),
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
      final currentUserId = employee?['id'];
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

      final items = _itemsByOrder[orderNumber];
      final item = items?.firstWhere(
        (i) => i['id'] == itemId,
        orElse: () => <String, dynamic>{},
      );
      if (item == null || item.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('품목 정보를 찾을 수 없습니다')),
        );
        return;
      }

      final input = await _showReceiveInputDialog(item);
      if (input == null) return;

      final int receivedQty = input['quantity'] as int;
      final DateTime actualDate = input['date'] as DateTime;
      final String note = (input['note'] as String?)?.trim() ?? '';

      final int requestedQty = (item['quantity'] ?? 0) as int;
      final bool fullyReceived = receivedQty >= requestedQty;
      final String deliveryStatus = fullyReceived ? 'received' : 'partial';

      // purchase_request_items 테이블의 특정 품목 업데이트
      await _supabase
          .from('purchase_request_items')
          .update({
            'is_received': fullyReceived,
            'received_quantity': receivedQty,
            'actual_received_date': actualDate.toIso8601String(),
            'delivery_status': deliveryStatus,
            'received_at': DateTime.now().toIso8601String(),
            'received_by': currentUserId,
            'received_by_name': userName,
            if (note.isNotEmpty) 'delivery_notes': note,
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
          SnackBar(content: Text(fullyReceived ? '입고 완료 처리되었습니다' : '부분 입고 처리되었습니다')),
        );
      }

      // 로컬 상태 업데이트 (전체 새로고침 대신)
      setState(() {
        // 1. 해당 품목의 is_received 상태 변경
        final items = _itemsByOrder[orderNumber];
        final itemIndex = items?.indexWhere((i) => i['id'] == itemId);
        if (itemIndex != null && itemIndex >= 0 && items != null) {
          items[itemIndex]['is_received'] = fullyReceived;
          items[itemIndex]['received_quantity'] = receivedQty;
          items[itemIndex]['actual_received_date'] = actualDate.toIso8601String();
          items[itemIndex]['delivery_status'] = deliveryStatus;
          items[itemIndex]['received_at'] = DateTime.now().toUtc().toIso8601String();
          items[itemIndex]['received_by'] = currentUserId;
          items[itemIndex]['received_by_name'] = userName;
          items[itemIndex]['delivery_notes'] = note;
        }
        
        // 2. 진행률 다시 계산
        _updateProgressForOrder(orderNumber);
        
        // 3. 필터링된 데이터도 업데이트
        _filterItems();
      });
    } catch (e) {
      // 에러 로깅 제겄됨 (Production 코드)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('입고완료 처리 중 오류가 발생했습니다')),
        );
      }
    }
  }

  // 특정 발주번호의 진행률 업데이트 (로컬 상태 업데이트용)
  void _updateProgressForOrder(String orderNumber) {
    final items = _itemsByOrder[orderNumber];
    if (items == null) return;

    final totalItems = items.length;
    final completedItems = items.where((item) => item['is_received'] == true).length;
    final remainingItems = totalItems - completedItems;

    _progressData[orderNumber] = {
      'total': totalItems,
      'completed': completedItems,
      'remaining': remainingItems,
    };
  }

  // 부서-직원 필터 UI 구성
  Widget _buildDepartmentEmployeeFilters() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        ResponsiveUtils.spacing(context, 20),
        ResponsiveUtils.spacing(context, 0),
        ResponsiveUtils.spacing(context, 20),
        ResponsiveUtils.spacing(context, 15),
      ),
      child: Row(
        children: [
          // 부서 필터
          Expanded(
            flex: 1,
            child: Container(
              height: ResponsiveUtils.spacing(context, 36),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDepartment,
                  hint: Text(
                    '부서 선택',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 13,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: const Color(0xFF8E8E93),
                    size: ResponsiveUtils.iconSize(context, 18),
                  ),
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 13,
                    color: const Color(0xFF1C1C1E),
                  ),
                  dropdownColor: Colors.white,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 8,
                  items: _departments.map<DropdownMenuItem<String>>((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacing(context, 12)),
                        child: Text(
                          department,
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 13,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _isLoadingDepartments ? null : _onDepartmentChanged,
                ),
              ),
            ),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 12)),
          // 직원 필터
          Expanded(
            flex: 1,
            child: Container(
              height: ResponsiveUtils.spacing(context, 36),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedEmployee,
                  hint: Text(
                    '이름 선택',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 13,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: const Color(0xFF8E8E93),
                    size: ResponsiveUtils.iconSize(context, 18),
                  ),
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 13,
                    color: const Color(0xFF1C1C1E),
                  ),
                  dropdownColor: Colors.white,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 8,
                  items: _employees.map<DropdownMenuItem<String>>((String employee) {
                    return DropdownMenuItem<String>(
                      value: employee,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacing(context, 12)),
                        child: Text(
                          employee,
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 13,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _onEmployeeChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 검색창과 리스트를 포함하는 컬럼
    return Column(
      children: [
        // 부서-이름 필터 (검색창 위에 배치)
        _buildDepartmentEmployeeFilters(),
        // 검색창 (컴팩트 디자인)
        Container(
          padding: EdgeInsets.fromLTRB(
            ResponsiveUtils.spacing(context, 20),
            ResponsiveUtils.spacing(context, 0),
            ResponsiveUtils.spacing(context, 20),
            ResponsiveUtils.spacing(context, 15),
          ),
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
        // 현재 필터 및 검색 결과 표시
        Container(
          padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacing(context, 16)),
          child: Row(
            children: [
              // 현재 필터 정보
              Icon(
                Icons.filter_alt_outlined,
                size: ResponsiveUtils.iconSize(context, 16),
                color: const Color(0xFF8E8E93),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 4)),
              Text(
                '필터: ${_selectedDepartment ?? "전체"} > ${_selectedEmployee ?? "전체"}',
                style: ResponsiveUtils.getTextStyle(
                  context,
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 검색 결과 (검색시에만 표시)
              if (_searchQuery.isNotEmpty) ...[
                Icon(
                  Icons.search,
                  size: ResponsiveUtils.iconSize(context, 16),
                  color: const Color(0xFF8E8E93),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                Text(
                  '검색: ${_filteredItemsByOrder.length}건',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ] else ...[
                Text(
                  '총 ${_filteredItemsByOrder.length}건',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.spacing(context, 8)),
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
        onRefresh: _loadReceivingItems,
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
            ),
          ],
        ),
      );
    }

    if (itemsToShow.isEmpty && _searchQuery.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _loadReceivingItems,
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
                                      // 수정요청 버튼 (요청자 본인만 표시)
                                      _buildEditRequestButton(context, orderNumber, firstItem),
                                      // app_admin 직접 수정 버튼
                                      _buildAdminEditButton(context, orderNumber, items),
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
                                          '입고예정일',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                        Text(
                                          firstItem['delivery_request_date'] != null && firstItem['delivery_request_date'].toString().isNotEmpty
                                              ? dateFormat.format(DateTime.parse(firstItem['delivery_request_date']))
                                              : '미정',
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
                            SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                            // 변경 입고예정일 정보
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_calendar_outlined,
                                    color: const Color(0xFF8E8E93),
                                    size: ResponsiveUtils.iconSize(context, 16),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '변경입고일',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                        Text(
                                          firstItem['revised_delivery_request_date'] != null && firstItem['revised_delivery_request_date'].toString().isNotEmpty
                                              ? dateFormat.format(DateTime.parse(firstItem['revised_delivery_request_date']))
                                              : '미정',
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
                        final deliveryStatus = item['delivery_status']?.toString() ?? 'pending';
                        final receivedQty = item['received_quantity'] as int?;
                        final actualReceivedDateStr = item['actual_received_date']?.toString();

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
                                      if (deliveryStatus == 'partial')
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveUtils.spacing(context, 6),
                                            vertical: ResponsiveUtils.spacing(context, 2),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                                            border: Border.all(
                                              color: Colors.orange.withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '부분입고',
                                            style: ResponsiveUtils.getTextStyle(
                                              context,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        )
                                      else if (isReceived)
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '금액: ${numberFormat.format(item['amount_value'])}원',
                                          style: ResponsiveUtils.getTextStyle(
                                            context,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (receivedQty != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 4)),
                                            child: Text(
                                              '실입고 수량: $receivedQty',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 13,
                                                color: const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ),
                                        if (actualReceivedDateStr != null && actualReceivedDateStr.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 2)),
                                            child: Text(
                                              '실입고일: ${_dateFormat.format(DateTime.parse(actualReceivedDateStr))}',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 13,
                                                color: const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ),
                                        if ((item['delivery_notes']?.toString().trim().isNotEmpty ?? false))
                                          Padding(
                                            padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 2)),
                                            child: Text(
                                              '비고: ${item['delivery_notes']}',
                                              style: ResponsiveUtils.getTextStyle(
                                                context,
                                                fontSize: 13,
                                                color: const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ),
                                      ],
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
    final TextEditingController subjectController = TextEditingController(
      text: '[수정요청] 발주번호 $orderNumber 수정 요청합니다.',
    );
    final TextEditingController contentController = TextEditingController();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final userName = employee?['name'] as String? ?? '';
    final userEmail = employee?['email'] as String? ?? '';
    final vendorName = firstItem['vendor_name'] as String? ?? '업체명 없음';
    final String? requesterId = (firstItem['requester_id'] ?? firstItem['requesterId'])?.toString();
    final int? purchaseId = (firstItem['purchase_id'] ?? firstItem['purchaseId']) as int?;
    final itemsForOrder = _itemsByOrder[orderNumber] ?? [];
    
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
                // 수정요청 제목 입력
                Row(
                  children: [
                    Icon(
                      Icons.title,
                      color: AppColors.primary,
                      size: ResponsiveUtils.iconSize(context, 20),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    Text(
                      '수정요청 제목 *',
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
                  controller: subjectController,
                  decoration: InputDecoration(
                    hintText: '[수정요청] 발주번호 $orderNumber 수정 요청합니다.',
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
                  '웹과 동일한 제목 형식을 사용합니다.',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 16)),
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
                final subject = subjectController.text.trim();
                final content = contentController.text.trim();
                if (subject.isEmpty || content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        subject.isEmpty ? '제목을 입력해주세요.' : '수정요청 내용을 입력해주세요.',
                      ),
                      backgroundColor: const Color(0xFFEF4444),
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
    if (result == true && subjectController.text.trim().isNotEmpty && contentController.text.trim().isNotEmpty) {
      await _submitEditRequest(
        orderNumber: orderNumber,
        subject: subjectController.text.trim(),
        vendorName: vendorName,
        content: contentController.text.trim(),
        userName: userName,
        userEmail: userEmail,
        requesterId: requesterId,
        purchaseId: purchaseId,
        itemsForOrder: itemsForOrder,
      );
    }
  }
  
  // 수정요청 등록 처리
  Future<void> _submitEditRequest({
    required String orderNumber,
    required String subject,
    required String vendorName,
    required String content,
    required String userName,
    required String userEmail,
    required List<Map<String, dynamic>> itemsForOrder,
    String? requesterId,
    int? purchaseId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 필요합니다.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }
      
      // 합계 및 아이템 수 계산
      final double totalAmount = itemsForOrder.fold<double>(0, (sum, item) {
        final amount = item['amount_value'];
        if (amount is num) return sum + amount.toDouble();
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice = (item['unit_price_value'] as num?)?.toDouble() ?? 0;
        return sum + (quantity * unitPrice);
      });
      final purchaseInfo = jsonEncode({
        'vendor_name': vendorName,
        'total_amount': totalAmount,
        'item_count': itemsForOrder.length,
      });
      
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
        inquiryType: 'modify',
        subject: subject,
        message: content,
        userName: userName,
        userEmail: userEmail,
        purchaseRequestId: purchaseId,
        purchaseOrderNumber: orderNumber,
        requesterId: requesterId,
        purchaseInfo: purchaseInfo,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '수정 요청이 전송되었습니다.'),
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

  // app_admin 직접 수정 버튼 빌드
  Widget _buildAdminEditButton(BuildContext context, String orderNumber, List<Map<String, dynamic>> items) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final purchaseRole = employee?['purchase_role'] as List<dynamic>? ?? [];
    
    // app_admin만 직접 수정 가능
    if (!UserRoleHelper.isAppAdmin(purchaseRole)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(left: ResponsiveUtils.spacing(context, 8)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAdminEditDialog(context, orderNumber, items),
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 12),
              vertical: ResponsiveUtils.spacing(context, 6),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: ResponsiveUtils.iconSize(context, 14),
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                Text(
                  '수정',
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // app_admin 직접 수정 다이얼로그 표시
  void _showAdminEditDialog(BuildContext context, String orderNumber, List<Map<String, dynamic>> items) {
    final firstItem = items.isNotEmpty ? items.first : {};
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AdminEditDialog(
          orderNumber: orderNumber,
          items: items,
          onSave: () {
            _loadReceivingItems(); // 저장 후 목록 새로고침
          },
        );
      },
    );
  }

  // 전체 입고완료용 날짜 선택 + 안내문 포함 커스텀 픽커
  Future<DateTime?> _showReceiveDatePicker({
    required BuildContext context,
    required DateTime initialDate,
  }) async {
    DateTime tempDate = initialDate;

    return showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            '날짜 선택',
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: SizedBox(
            width: 360, // 명시적 너비 부여로 Intrinsic 측정 방지
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 320, // 높이 고정으로 CalendarDatePicker intrinsic 측정 회피
                  child: CalendarDatePicker(
                    initialDate: tempDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    onDateChanged: (picked) {
                      tempDate = picked;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '요청입고수량과 동일한 수량으로 입력됩니다.',
                          style: ResponsiveUtils.getTextStyle(
                            context,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                foregroundColor: const Color(0xFF6B7280),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(tempDate),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

// app_admin 수정 다이얼로그
class AdminEditDialog extends StatefulWidget {
  final String orderNumber;
  final List<Map<String, dynamic>> items;
  final VoidCallback onSave;

  const AdminEditDialog({
    super.key,
    required this.orderNumber,
    required this.items,
    required this.onSave,
  });

  @override
  State<AdminEditDialog> createState() => _AdminEditDialogState();
}

class _AdminEditDialogState extends State<AdminEditDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  // 공통 정보 수정 필드들
  late TextEditingController _vendorController;
  String _selectedCategory = '';
  DateTime? _expectedDeliveryDate;
  DateTime? _revisedDeliveryDate;
  
  // 품목별 수정 필드들
  List<Map<String, TextEditingController>> _itemControllers = [];
  
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _vendorController.dispose();
    for (final controllers in _itemControllers) {
      controllers.values.forEach((controller) => controller.dispose());
    }
    super.dispose();
  }

  void _initializeControllers() {
    final firstItem = widget.items.isNotEmpty ? widget.items.first : {};
    
    // 공통 정보 초기화
    _vendorController = TextEditingController(text: firstItem['vendor_name'] ?? '');
    _selectedCategory = firstItem['payment_category'] ?? '';
    
    // 입고예정일 초기화
    final expectedDateStr = firstItem['delivery_request_date'] as String?;
    if (expectedDateStr != null && expectedDateStr.isNotEmpty) {
      try {
        _expectedDeliveryDate = DateTime.parse(expectedDateStr);
      } catch (e) {
        _expectedDeliveryDate = null;
      }
    }
    
    // 변경요청일 초기화
    final revisedDateStr = firstItem['revised_delivery_request_date'] as String?;
    if (revisedDateStr != null && revisedDateStr.isNotEmpty) {
      try {
        _revisedDeliveryDate = DateTime.parse(revisedDateStr);
      } catch (e) {
        _revisedDeliveryDate = null;
      }
    }
    
    // 품목별 컨트롤러 초기화
    _itemControllers = widget.items.map((item) {
      return {
        'item_name': TextEditingController(text: item['item_name'] ?? ''),
        'specification': TextEditingController(text: item['specification'] ?? ''),
        'quantity': TextEditingController(text: (item['quantity'] ?? 0).toString()),
        'unit_price': TextEditingController(text: (item['unit_price_value'] ?? 0).toString()),
        'remark': TextEditingController(text: item['remark'] ?? ''),
      };
    }).toList();
    
    // 변경 감지 리스너 추가
    _vendorController.addListener(_onFieldChanged);
    for (final controllers in _itemControllers) {
      controllers.values.forEach((controller) => controller.addListener(_onFieldChanged));
    }
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
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
                  Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: ResponsiveUtils.iconSize(context, 24),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                  Expanded(
                    child: Text(
                      '발주 정보 수정',
                      style: ResponsiveUtils.getTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_hasChanges)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 8),
                        vertical: ResponsiveUtils.spacing(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                      ),
                      child: Text(
                        '수정됨',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // 내용
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 발주번호 (읽기 전용)
                      _buildInfoCard('발주번호', widget.orderNumber),
                      SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                      
                      // 공통 정보 수정
                      _buildSectionHeader('공통 정보'),
                      SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                      
                      _buildTextField(
                        controller: _vendorController,
                        label: '업체명',
                        icon: Icons.business,
                        validator: (value) => value?.trim().isEmpty == true ? '업체명을 입력해주세요' : null,
                      ),
                      SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                      
                      _buildCategoryDropdown(),
                      SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                      
                      // 입고예정일 선택
                      _buildDateField(),
                      SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                      // 변경요청일 선택
                      _buildRevisedDateField(),
                      SizedBox(height: ResponsiveUtils.spacing(context, 24)),
                      
                      // 품목 정보 수정
                      _buildSectionHeader('품목 정보'),
                      SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                      
                      ...List.generate(widget.items.length, (index) {
                        return Column(
                          children: [
                            _buildItemCard(index),
                            if (index < widget.items.length - 1)
                              SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            
            // 버튼
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 16)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: ResponsiveUtils.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading || !_hasChanges ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacing(context, 16)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              '저장',
                              style: ResponsiveUtils.getTextStyle(
                                context,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.primary,
            size: ResponsiveUtils.iconSize(context, 20),
          ),
          SizedBox(width: ResponsiveUtils.spacing(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                Text(
                  value,
                  style: ResponsiveUtils.getTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: ResponsiveUtils.getTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    const categories = ['발주', '구매 요청', '현장 결제'];
    
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory.isNotEmpty && categories.contains(_selectedCategory) 
          ? _selectedCategory 
          : null,
      decoration: InputDecoration(
        labelText: '카테고리',
        prefixIcon: Icon(Icons.category, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: categories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(
            category,
            style: ResponsiveUtils.getTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedCategory = newValue;
            _onFieldChanged();
          });
        }
      },
      validator: (value) => value == null || value.isEmpty ? '카테고리를 선택해주세요' : null,
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 16),
          vertical: ResponsiveUtils.spacing(context, 16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: AppColors.primary,
              size: ResponsiveUtils.iconSize(context, 20),
            ),
            SizedBox(width: ResponsiveUtils.spacing(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '입고예정일',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    _expectedDeliveryDate != null
                        ? DateFormat('yyyy년 MM월 dd일').format(_expectedDeliveryDate!)
                        : '날짜를 선택해주세요',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _expectedDeliveryDate != null
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: const Color(0xFF9CA3AF),
              size: ResponsiveUtils.iconSize(context, 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisedDateField() {
    return GestureDetector(
      onTap: _selectRevisedDate,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacing(context, 16),
          vertical: ResponsiveUtils.spacing(context, 16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event,
              color: AppColors.primary,
              size: ResponsiveUtils.iconSize(context, 20),
            ),
            SizedBox(width: ResponsiveUtils.spacing(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '변경요청일',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    _revisedDeliveryDate != null
                        ? DateFormat('yyyy년 MM월 dd일').format(_revisedDeliveryDate!)
                        : '날짜를 선택해주세요',
                    style: ResponsiveUtils.getTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _revisedDeliveryDate != null
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: const Color(0xFF9CA3AF),
              size: ResponsiveUtils.iconSize(context, 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expectedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _expectedDeliveryDate) {
      setState(() {
        _expectedDeliveryDate = pickedDate;
        _onFieldChanged();
      });
    }
  }

  Future<void> _selectRevisedDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _revisedDeliveryDate ?? (_expectedDeliveryDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _revisedDeliveryDate) {
      setState(() {
        _revisedDeliveryDate = pickedDate;
        _onFieldChanged();
      });
    }
  }

  Widget _buildItemCard(int index) {
    final item = widget.items[index];
    final controllers = _itemControllers[index];
    
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 품목 헤더
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 8),
                  vertical: ResponsiveUtils.spacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 6)),
                ),
                child: Text(
                  '품목 ${index + 1}',
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
          SizedBox(height: ResponsiveUtils.spacing(context, 16)),
          
          // 품목명
          _buildTextField(
            controller: controllers['item_name']!,
            label: '품목명',
            icon: Icons.inventory_2,
            validator: (value) => value?.trim().isEmpty == true ? '품목명을 입력해주세요' : null,
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
          
          // 규격
          _buildTextField(
            controller: controllers['specification']!,
            label: '규격',
            icon: Icons.straighten,
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
          
          // 수량과 단가
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: controllers['quantity']!,
                  label: '수량',
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return '수량을 입력해주세요';
                    final num = int.tryParse(value!);
                    if (num == null || num <= 0) return '유효한 수량을 입력해주세요';
                    return null;
                  },
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 12)),
              Expanded(
                child: _buildTextField(
                  controller: controllers['unit_price']!,
                  label: '단가',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return '단가를 입력해주세요';
                    final num = double.tryParse(value!);
                    if (num == null || num < 0) return '유효한 단가를 입력해주세요';
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacing(context, 12)),
          
          // 비고
          _buildTextField(
            controller: controllers['remark']!,
            label: '비고',
            icon: Icons.note,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 공통 정보 업데이트
      final vendorName = _vendorController.text.trim();
      final category = _selectedCategory;
      final expectedDate = _expectedDeliveryDate?.toIso8601String().split('T')[0];
      final revisedDate = _revisedDeliveryDate?.toIso8601String().split('T')[0];

      // 각 품목 정보 업데이트
      for (int i = 0; i < widget.items.length; i++) {
        final item = widget.items[i];
        final controllers = _itemControllers[i];
        
        final itemName = controllers['item_name']!.text.trim();
        final specification = controllers['specification']!.text.trim();
        final quantity = int.tryParse(controllers['quantity']!.text.trim()) ?? 0;
        final unitPrice = double.tryParse(controllers['unit_price']!.text.trim()) ?? 0.0;
        final remark = controllers['remark']!.text.trim();
        final amount = quantity * unitPrice;

        await _supabase
            .from('purchase_request_items')
            .update({
              'vendor_name': vendorName,
              'payment_category': category,
              'item_name': itemName,
              'specification': specification,
              'quantity': quantity,
              'unit_price_value': unitPrice,
              'amount_value': amount,
              'remark': remark,
            })
            .eq('id', item['id']);
      }

      // 공통 정보는 purchase_requests 테이블 업데이트
      await _supabase
          .from('purchase_requests')
          .update({
            'delivery_request_date': expectedDate,
            'revised_delivery_request_date': revisedDate,
          })
          .eq('purchase_order_number', widget.orderNumber);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정이 완료되었습니다.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수정 중 오류가 발생했습니다: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}