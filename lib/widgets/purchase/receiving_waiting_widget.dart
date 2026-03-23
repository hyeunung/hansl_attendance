import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import '../../utils/responsive_utils.dart';
import '../shared/flat_section.dart';
import '../../utils/user_role_helper.dart';
import '../../services/inquiry_service.dart';
import '../../widgets/common/notification_banner_widget.dart';
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
                    style: AppTextStyles.cardTitle(context).copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['item_name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.inputLabel(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '요청 수량 ${requestedQty}개',
                    style: AppTextStyles.tableHeader(context).copyWith(
                      color: AppColors.gray400,
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
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                      Text(
                        '실제 입고일',
                            style: AppTextStyles.inputLabel(context).copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _dateFormat.format(selectedDate),
                            style: AppTextStyles.inputLabel(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.gray400),
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
                        style: AppTextStyles.inputLabel(context).copyWith(
                          fontWeight: FontWeight.w400,
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
                      helperStyle: AppTextStyles.compactLabel(context).copyWith(
                        color: AppColors.gray400,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
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
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
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
                    foregroundColor: AppColors.textSecondary,
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
                        backgroundColor: isValid ? AppColors.primary : AppColors.gray300,
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
      final purchaseRoles = UserRoleHelper.getRoles(employee);
      
      // superadmin의 경우 기본값을 "전체"로 설정
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
      final purchaseRoles = UserRoleHelper.getRoles(employee);
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
      // - superadmin: 전체 보기
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
      final purchaseRoles = UserRoleHelper.getRoles(employee);
      final userName = employee?['name'] as String? ?? '';
      
      // 권한 체크: superadmin, pure lead buyer, 또는 본인 요청자만 가능
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
          AppBanner.show(context, '입고 완료 권한이 없습니다', type: BannerType.warning);
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
          AppBanner.show(context, '이미 모든 품목이 입고완료되었습니다', type: BannerType.info);
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
        AppBanner.show(context, '${unreceivedItems.length}건의 품목이 입고완료 처리되었습니다', type: BannerType.success);
      }

      // 데이터 새로고침
      await _loadReceivingItems();

    } catch (e) {
      // 에러 발생 시 UI 상태 되돌리기
      await _loadReceivingItems();

      if (mounted) {
        AppBanner.show(context, '전체 입고완료 처리 중 오류가 발생했습니다', type: BannerType.error);
      }
    }
  }

  // 품목별 입고완료 처리
  Future<void> _completeReceivingForItem(String orderNumber, int itemId) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final employee = userProvider.employee;
      final currentUserId = employee?['id'];
      final purchaseRoles = UserRoleHelper.getRoles(employee);
      final userName = employee?['name'] as String? ?? '';
      
      // 권한 체크: superadmin, pure lead buyer, 또는 본인 요청자만 가능
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
        AppBanner.show(context, '입고 완료 권한이 없습니다', type: BannerType.warning);
        return;
      }

      final items = _itemsByOrder[orderNumber];
      final item = items?.firstWhere(
        (i) => i['id'] == itemId,
        orElse: () => <String, dynamic>{},
      );
      if (item == null || item.isEmpty) {
        AppBanner.show(context, '품목 정보를 찾을 수 없습니다', type: BannerType.error);
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
        AppBanner.show(context, fullyReceived ? '입고 완료 처리되었습니다' : '부분 입고 처리되었습니다', type: BannerType.success);
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
      // 에러 로깅 제거됨 (Production 코드)
      if (mounted) {
        AppBanner.show(context, '입고완료 처리 중 오류가 발생했습니다', type: BannerType.error);
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
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDepartment,
                  hint: Text(
                    '부서 선택',
                    style: AppTextStyles.cardCaption(context),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textTertiary,
                    size: ResponsiveUtils.iconSize(context, 18),
                  ),
                  style: AppTextStyles.chipLabel(context, color: AppColors.textPrimary),
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
                          style: AppTextStyles.chipLabel(context, color: AppColors.textPrimary),
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
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 8)),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedEmployee,
                  hint: Text(
                    '이름 선택',
                    style: AppTextStyles.cardCaption(context),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textTertiary,
                    size: ResponsiveUtils.iconSize(context, 18),
                  ),
                  style: AppTextStyles.chipLabel(context, color: AppColors.textPrimary),
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
                          style: AppTextStyles.chipLabel(context, color: AppColors.textPrimary),
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
                hintStyle: AppTextStyles.tableHeader(context),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textTertiary,
                  size: ResponsiveUtils.iconSize(context, 18),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear, 
                          color: AppColors.textTertiary,
                          size: ResponsiveUtils.iconSize(context, 18),
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
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacing(context, 12),
                  vertical: ResponsiveUtils.spacing(context, 6),
                ),
                isDense: true,
              ),
              style: AppTextStyles.chipLabel(context, color: AppColors.textPrimary),
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
                color: AppColors.textTertiary,
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 4)),
              Text(
                '필터: ${_selectedDepartment ?? "전체"} > ${_selectedEmployee ?? "전체"}',
                style: AppTextStyles.tableHeader(context).copyWith(
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
                  color: AppColors.textTertiary,
                ),
                SizedBox(width: ResponsiveUtils.spacing(context, 4)),
                Text(
                  '검색: ${_filteredItemsByOrder.length}건',
                  style: AppTextStyles.tableHeader(context),
                ),
              ] else ...[
                Text(
                  '총 ${_filteredItemsByOrder.length}건',
                  style: AppTextStyles.tableHeader(context),
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
        onRefresh: () async {
          await _loadReceivingItems();
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
                    Icons.inventory_2_outlined,
                    size: ResponsiveUtils.iconSize(context, 80),
                    color: AppColors.border,
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                  Text(
                    '입고대기 항목이 없습니다',
                    style: AppTextStyles.cardTitle(context),
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
        onRefresh: () async {
          await _loadReceivingItems();
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
                    Icons.search_off,
                    size: ResponsiveUtils.iconSize(context, 80),
                    color: AppColors.border,
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 20)),
                  Text(
                    '검색 결과가 없습니다',
                    style: AppTextStyles.cardTitle(context),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                  Text(
                    '다른 검색어를 시도해보세요',
                    style: AppTextStyles.emptyState(context),
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
          final purchaseRoles = UserRoleHelper.getRoles(employee);
          final userName = employee?['name'] as String? ?? '';
          
          // 입고완료 버튼 표시 여부
          final canComplete = UserRoleHelper.isAppAdmin(purchaseRoles) || 
                            UserRoleHelper.isPureLeadBuyer(purchaseRoles) ||
                            firstItem['requester_name'] == userName;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
                left: isExpanded ? BorderSide(color: AppColors.primary, width: 3) : BorderSide.none,
              ),
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
                      color: isExpanded ? AppColors.backgroundSecondary : Colors.white,
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
                                          style: AppTextStyles.cardTitle(context),
                                        ),
                                      ),
                                      // 수정요청 버튼 (요청자 본인만 표시)
                                      _buildEditRequestButton(context, orderNumber, firstItem),
                                      // superadmin 직접 수정 버튼
                                      _buildAdminEditButton(context, orderNumber, items),
                                    ],
                                  ),
                                  SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                                  // 업체명
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        color: AppColors.textTertiary,
                                        size: ResponsiveUtils.iconSize(context, 16),
                                      ),
                                      SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                      Expanded(
                                        child: Text(
                                          firstItem['vendor_name'] ?? '업체명 없음',
                                          style: AppTextStyles.listTitle(context).copyWith(
                                            color: AppColors.gray700,
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
                                    color: AppColors.textTertiary,
                                    size: ResponsiveUtils.iconSize(context, 16),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                  Flexible(
                                    child: Text(
                                      firstItem['requester_name'] ?? '요청자 없음',
                                      style: AppTextStyles.tableCellSub(context),
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
                                    color: AppColors.textTertiary,
                                    size: ResponsiveUtils.iconSize(context, 16),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '입고예정일',
                                          style: AppTextStyles.tableHeader(context),
                                        ),
                                        Text(
                                          firstItem['delivery_request_date'] != null && firstItem['delivery_request_date'].toString().isNotEmpty
                                              ? dateFormat.format(DateTime.parse(firstItem['delivery_request_date']))
                                              : '미정',
                                          style: AppTextStyles.inputLabel(context).copyWith(
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
                                    color: AppColors.textTertiary,
                                    size: ResponsiveUtils.iconSize(context, 16),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '변경입고일',
                                          style: AppTextStyles.tableHeader(context),
                                        ),
                                        Text(
                                          firstItem['revised_delivery_request_date'] != null && firstItem['revised_delivery_request_date'].toString().isNotEmpty
                                              ? dateFormat.format(DateTime.parse(firstItem['revised_delivery_request_date']))
                                              : '미정',
                                          style: AppTextStyles.inputLabel(context).copyWith(
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
                            color: AppColors.textTertiary,
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
                          color: AppColors.border.withValues(alpha: 0.5),
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
                            color: isReceived ? AppColors.infoLight : Colors.transparent,
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
                                  color: isReceived ? AppColors.primary : AppColors.border,
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
                                            style: AppTextStyles.tableCell(context, color: isReceived ? AppColors.textTertiary : null).copyWith(
                                              decoration: isReceived ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                      if (deliveryStatus == 'partial')
                                        StatusChip(
                                          label: '부분입고',
                                          color: AppColors.warning,
                                        )
                                      else if (isReceived)
                                        StatusChip(
                                          label: '완료됨',
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                    if (item['specification'] != null)
                                      Text(
                                        '규격: ${item['specification']}',
                                        style: AppTextStyles.tableCellSub(context),
                                      ),
                                    SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                                    Row(
                                      children: [
                                        Text(
                                          '수량: ${item['quantity']}',
                                          style: AppTextStyles.listSubtitle(context).copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        SizedBox(width: ResponsiveUtils.spacing(context, 12)),
                                        Text(
                                          '단가: ${numberFormat.format(item['unit_price_value'])}원',
                                          style: AppTextStyles.listSubtitle(context).copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '금액: ${numberFormat.format(item['amount_value'])}원',
                                          style: AppTextStyles.tableCellSub(context).copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (receivedQty != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 4)),
                                            child: Text(
                                              '실입고 수량: $receivedQty',
                                              style: AppTextStyles.listSubtitle(context).copyWith(
                                                color: AppColors.gray700,
                                              ),
                                            ),
                                          ),
                                        if (actualReceivedDateStr != null && actualReceivedDateStr.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 2)),
                                            child: Text(
                                              '실입고일: ${_dateFormat.format(DateTime.parse(actualReceivedDateStr))}',
                                              style: AppTextStyles.cardCaption(context).copyWith(
                                                color: AppColors.gray700,
                                              ),
                                            ),
                                          ),
                                        if ((item['delivery_notes']?.toString().trim().isNotEmpty ?? false))
                                          Padding(
                                            padding: EdgeInsets.only(top: ResponsiveUtils.spacing(context, 2)),
                                            child: Text(
                                              '비고: ${item['delivery_notes']}',
                                              style: AppTextStyles.cardCaption(context).copyWith(
                                                color: AppColors.gray700,
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
                                    backgroundColor: AppColors.info,
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
                                    style: AppTextStyles.chipSmall(context, color: Colors.white).copyWith(
                                      fontSize: 12,
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
            color: AppColors.infoLight,
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
                        style: AppTextStyles.listTitle(context).copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${percentage}% (${receivedItems}/${totalItems})',
                    style: AppTextStyles.inputLabel(context).copyWith(
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
                  color: AppColors.infoLight,
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
                            color: AppColors.infoLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 6)),
                        Text(
                          '대기: ${pendingItems}건',
                          style: AppTextStyles.tableHeader(context).copyWith(
                            color: AppColors.primary,
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
                          style: AppTextStyles.tableHeader(context).copyWith(
                            color: AppColors.primary,
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
    final purchaseRoles = UserRoleHelper.getRoles(employee);
    final currentUserName = employee?['name'] as String? ?? '';
    
    // 권한 체크: superadmin, lead_buyer, 또는 본인 요청한 것만 전체완료 가능
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
                color: AppColors.textTertiary,
                size: ResponsiveUtils.iconSize(context, 16),
              ),
              SizedBox(width: ResponsiveUtils.spacing(context, 6)),
              Text(
                percentage == 100 ? '모든 품목이 입고완료되었습니다' : '미완료 품목: ${pendingItems.length}건',
                style: AppTextStyles.tableHeader(context),
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
              style: AppTextStyles.chipLabel(context, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
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
    final purchaseRoles = UserRoleHelper.getRoles(employee);
    final currentUserName = employee?['name'] as String? ?? '';
    final requesterName = firstItem['requester_name'] as String? ?? '';
    
    // 관리자 계정은 수정요청 버튼 미노출
    if (UserRoleHelper.isAppAdmin(purchaseRoles)) {
      return const SizedBox.shrink();
    }

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
                  style: AppTextStyles.chipSmall(context, color: AppColors.primary).copyWith(
                    fontSize: 12,
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final userName = employee?['name'] as String? ?? '';
    final userEmail = employee?['email'] as String? ?? '';
    final vendorName = firstItem['vendor_name'] as String? ?? '업체명 없음';
    final String? requesterId = (firstItem['requester_id'] ?? firstItem['requesterId'])?.toString();
    final int? purchaseId = (firstItem['purchase_id'] ?? firstItem['purchaseId']) as int?;
    final itemsForOrder = _itemsByOrder[orderNumber] ?? [];
    final currentDeliveryDate = firstItem['delivery_request_date']?.toString();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ModifyRequestDialog(
          orderNumber: orderNumber,
          vendorName: vendorName,
          currentDeliveryDate: currentDeliveryDate,
          requestDate: firstItem['request_date']?.toString(),
          createdAt: firstItem['created_at']?.toString(),
          itemsForOrder: itemsForOrder,
          onSubmit: ({
            required String inquiryType,
            required String message,
            DateTime? requestedDeliveryDate,
            required List<_QuantityChangeRow> quantityRows,
            required List<_PriceChangeRow> priceRows,
          }) {
            return _submitEditRequest(
              orderNumber: orderNumber,
              vendorName: vendorName,
              inquiryType: inquiryType,
              message: message,
              userName: userName,
              userEmail: userEmail,
              requesterId: requesterId,
              purchaseId: purchaseId,
              itemsForOrder: itemsForOrder,
              currentDeliveryDate: currentDeliveryDate,
              requestedDeliveryDate: requestedDeliveryDate,
              requestDate: firstItem['request_date']?.toString(),
              createdAt: firstItem['created_at']?.toString(),
              quantityRows: quantityRows,
              priceRows: priceRows,
            );
          },
        );
      },
    );
  }
  
  // 수정요청 등록 처리
  Future<bool> _submitEditRequest({
    required String orderNumber,
    required String vendorName,
    required String inquiryType,
    required String message,
    required String userName,
    required String userEmail,
    required List<Map<String, dynamic>> itemsForOrder,
    String? requesterId,
    int? purchaseId,
    String? currentDeliveryDate,
    DateTime? requestedDeliveryDate,
    String? requestDate,
    String? createdAt,
    List<_QuantityChangeRow> quantityRows = const [],
    List<_PriceChangeRow> priceRows = const [],
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          AppBanner.show(context, '로그인이 필요합니다.', type: BannerType.error);
        }
        return false;
      }
      
      num? toNum(dynamic value) {
        if (value is num) return value;
        if (value is String) return num.tryParse(value);
        return null;
      }

      final numberFormat = NumberFormat('#,###');

      String formatDateText(String? value) {
        if (value == null || value.isEmpty) return '-';
        try {
          return _dateFormat.format(DateTime.parse(value).toLocal());
        } catch (_) {
          return value;
        }
      }

      final itemsText = itemsForOrder.map((item) {
        final line = item['line_number'] ?? '-';
        final name = item['item_name'] ?? '';
        final spec = item['specification'] ?? '-';
        final qty = item['quantity'] ?? 0;
        return '- $line. $name ($spec) ${qty}개';
      }).join('\n');

      final purchaseInfoText = '발주번호: $orderNumber\n'
          '업체: $vendorName\n'
          '요청자: $userName\n'
          '요청일: ${formatDateText(requestDate ?? createdAt)}\n'
          '품목:\n$itemsText';

      Map<String, dynamic>? inquiryPayload;
      final summaryLines = <String>[];

      if (inquiryType == 'delivery_date_change') {
        final requestedDateText = requestedDeliveryDate != null
            ? _dateFormat.format(requestedDeliveryDate)
            : null;
        inquiryPayload = {
          'requested_date': requestedDateText,
          'current_date': currentDeliveryDate,
        };
        summaryLines.add('현재 입고요청일: ${formatDateText(currentDeliveryDate)}');
        if (requestedDateText != null) {
          summaryLines.add('변경 입고일: $requestedDateText');
        }
      }

      if (inquiryType == 'quantity_change') {
        final payloadItems = <Map<String, dynamic>>[];
        for (final row in quantityRows) {
          final itemIndex = row.itemIndex;
          if (itemIndex == null || itemIndex < 0 || itemIndex >= itemsForOrder.length) continue;
          final item = itemsForOrder[itemIndex];
          final newQty = int.tryParse(row.controller.text.trim());
          payloadItems.add({
            'item_id': item['id']?.toString(),
            'line_number': item['line_number'],
            'item_name': item['item_name'],
            'specification': item['specification'],
            'current_quantity': item['quantity'],
            'new_quantity': newQty,
          });

          final currentQtyText = item['quantity']?.toString() ?? '-';
          summaryLines.add('품목: ${item['item_name'] ?? ''} (${item['specification'] ?? '-'}) / 현재 수량: $currentQtyText / 변경 수량: ${newQty ?? '-'}');
        }
        inquiryPayload = {'items': payloadItems};
      }

      if (inquiryType == 'price_change') {
        final payloadItems = <Map<String, dynamic>>[];
        for (final row in priceRows) {
          final itemIndex = row.itemIndex;
          if (itemIndex == null || itemIndex < 0 || itemIndex >= itemsForOrder.length) continue;
          final item = itemsForOrder[itemIndex];
          final newValue = int.tryParse(row.controller.text.trim());
          final currentUnitPrice = toNum(item['unit_price_value']);
          final currentAmount = toNum(item['amount_value']);

          payloadItems.add({
            'item_id': item['id']?.toString(),
            'line_number': item['line_number'],
            'item_name': item['item_name'],
            'specification': item['specification'],
            'change_type': row.changeType,
            'current_unit_price': currentUnitPrice,
            'new_unit_price': row.changeType == 'unit_price' ? newValue : null,
            'current_amount': currentAmount,
            'new_amount': row.changeType == 'amount' ? newValue : null,
          });

          if (row.changeType == 'amount') {
            summaryLines.add(
              '품목: ${item['item_name'] ?? ''} (${item['specification'] ?? '-'}) / 현재 합계액: ${currentAmount != null ? numberFormat.format(currentAmount) : '-'}원 / 변경 합계액: ${newValue != null ? numberFormat.format(newValue) : '-'}원',
            );
          } else {
            summaryLines.add(
              '품목: ${item['item_name'] ?? ''} (${item['specification'] ?? '-'}) / 현재 단가: ${currentUnitPrice != null ? numberFormat.format(currentUnitPrice) : '-'}원 / 변경 단가: ${newValue != null ? numberFormat.format(newValue) : '-'}원',
            );
          }
        }
        inquiryPayload = {'items': payloadItems};
      }

      if (inquiryType == 'delete') {
        inquiryPayload = {'reason': message.trim()};
      }

      final messageSections = [message.trim()];
      if (summaryLines.isNotEmpty) {
        messageSections.add('[요청 상세]\n${summaryLines.join('\n')}');
      }
      messageSections.add('[관련 발주 정보]\n$purchaseInfoText');
      final finalMessage = messageSections.join('\n\n');
      
      // 로딩 표시
      if (mounted) {
        AppBanner.show(context, '수정요청을 등록 중입니다...', type: BannerType.info);
      }
      
      final inquiryService = InquiryService();
      final result = await inquiryService.createInquiry(
        inquiryType: inquiryType,
        subject: InquiryService.getInquiryTypeLabel(inquiryType),
        message: finalMessage,
        userName: userName,
        userEmail: userEmail,
        purchaseRequestId: purchaseId,
        purchaseOrderNumber: orderNumber,
        requesterId: requesterId,
        purchaseInfo: purchaseInfoText,
        inquiryPayload: inquiryPayload,
        includeInitialMessage: false,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          AppBanner.show(context, result['message'] ?? '수정 요청이 전송되었습니다.', type: BannerType.success);
          return true;
        } else {
          AppBanner.show(context, result['message'] ?? '수정요청 등록에 실패했습니다.', type: BannerType.error);
          return false;
        }
      }
      return false;
    } catch (e) {
      if (mounted) {
        AppBanner.show(context, '수정요청 등록 중 오류가 발생했습니다.', type: BannerType.error);
      }
      return false;
    }
  }

  // 관리자 직접 수정 버튼 빌드
  Widget _buildAdminEditButton(BuildContext context, String orderNumber, List<Map<String, dynamic>> items) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employee = userProvider.employee;
    final purchaseRole = UserRoleHelper.getRoles(employee);
    
    // 관리자만 직접 수정 가능
    if (!UserRoleHelper.isAppAdmin(purchaseRole)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(left: ResponsiveUtils.spacing(context, 8)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAdminEditDialog(context, orderNumber, items),
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.spacing(context, 12),
              vertical: ResponsiveUtils.spacing(context, 6),
            ),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
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
                  style: AppTextStyles.chipSmall(context, color: Colors.white).copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // superadmin 직접 수정 다이얼로그 표시
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
            style: AppTextStyles.cardTitle(context).copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
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
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '요청입고수량과 동일한 수량으로 입력됩니다.',
                          style: AppTextStyles.cardCaption(context).copyWith(
                            color: AppColors.textPrimary,
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
                foregroundColor: AppColors.textSecondary,
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

typedef _ModifyRequestSubmit = Future<bool> Function({
  required String inquiryType,
  required String message,
  DateTime? requestedDeliveryDate,
  required List<_QuantityChangeRow> quantityRows,
  required List<_PriceChangeRow> priceRows,
});

class _ModifyRequestDialog extends StatefulWidget {
  final String orderNumber;
  final String vendorName;
  final String? currentDeliveryDate;
  final String? requestDate;
  final String? createdAt;
  final List<Map<String, dynamic>> itemsForOrder;
  final _ModifyRequestSubmit onSubmit;

  const _ModifyRequestDialog({
    required this.orderNumber,
    required this.vendorName,
    required this.currentDeliveryDate,
    required this.requestDate,
    required this.createdAt,
    required this.itemsForOrder,
    required this.onSubmit,
  });

  @override
  State<_ModifyRequestDialog> createState() => _ModifyRequestDialogState();
}

class _ModifyRequestDialogState extends State<_ModifyRequestDialog> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final TextEditingController _messageController = TextEditingController();
  final List<_QuantityChangeRow> _quantityRows = [];
  final List<_PriceChangeRow> _priceRows = [];
  final List<Map<String, String>> _typeOptions = const [
    {'value': 'delivery_date_change', 'label': '입고일 변경 요청'},
    {'value': 'quantity_change', 'label': '수량 변경 요청'},
    {'value': 'price_change', 'label': '단가/합계 금액 변경 요청'},
    {'value': 'modify', 'label': '수정 요청'},
    {'value': 'delete', 'label': '삭제 요청'},
  ];
  late final List<String> _itemLabels;
  late final List<DropdownMenuItem<int>> _itemOptions;
  late final String _itemsText;
  FlutterExceptionHandler? _previousFlutterErrorHandler;
  String? _uiErrorMessage;

  String? _selectedType;
  DateTime? _requestedDeliveryDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _itemLabels = widget.itemsForOrder.map(_buildItemLabel).toList();
    _itemOptions = _itemLabels.asMap().entries.map((entry) {
      return DropdownMenuItem<int>(
        value: entry.key,
        child: Text(
          entry.value,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }).toList();
    _itemsText = _itemLabels.join('\n');

    _previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _previousFlutterErrorHandler?.call(details);
      if (!mounted) return;
      setState(() {
        _uiErrorMessage = details.exceptionAsString();
      });
    };
  }

  @override
  void dispose() {
    FlutterError.onError = _previousFlutterErrorHandler;
    _messageController.dispose();
    for (final row in _quantityRows) {
      row.controller.dispose();
    }
    for (final row in _priceRows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  String _formatDateText(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      return _dateFormat.format(DateTime.parse(value).toLocal());
    } catch (_) {
      return value;
    }
  }

  String _buildItemLabel(Map<String, dynamic> item) {
    final line = item['line_number']?.toString() ?? '-';
    final name = item['item_name']?.toString() ?? '';
    final spec = item['specification']?.toString() ?? '-';
    return '$line. $name ($spec)';
  }

  void _ensureRowsForType(String? type) {
    if (type == 'quantity_change' && _quantityRows.isEmpty) {
      _quantityRows.add(_QuantityChangeRow());
    }
    if (type == 'price_change' && _priceRows.isEmpty) {
      _priceRows.add(_PriceChangeRow());
    }
  }

  String _getSelectedTypeLabel() {
    final match = _typeOptions.firstWhere(
      (option) => option['value'] == _selectedType,
      orElse: () => const {'value': '', 'label': ''},
    );
    return match['label'] ?? '';
  }

  List<DropdownMenuItem<String>> _buildTypeItems() {
    return _typeOptions.map((option) {
      return DropdownMenuItem<String>(
        value: option['value'],
        child: Text(option['label'] ?? ''),
      );
    }).toList();
  }

  List<Widget> _safeSection(List<Widget> Function() builder) {
    try {
      return builder();
    } catch (error) {
      return [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.errorLight),
          ),
          child: Text(
            '유형 섹션 렌더 오류: ${error.toString()}',
            style: AppTextStyles.tableHeader(context).copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      ];
    }
  }

  Widget _buildErrorBanner() {
    if (_uiErrorMessage == null || _uiErrorMessage!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 12)),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorLight),
      ),
      child: Text(
        '모달 렌더 오류: $_uiErrorMessage',
        style: AppTextStyles.tableHeader(context).copyWith(
          color: AppColors.error,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: ResponsiveUtils.iconSize(context, 20),
        ),
        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.sectionSubtitle(context),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final content = _messageController.text.trim();
    if (_selectedType == null || _selectedType!.isEmpty) {
      AppBanner.show(context, '문의 유형을 선택해주세요.', type: BannerType.error);
      return;
    }
    if (content.isEmpty) {
      AppBanner.show(context, '문의 내용을 입력해주세요.', type: BannerType.error);
      return;
    }

    if (_selectedType == 'delivery_date_change' && _requestedDeliveryDate == null) {
      AppBanner.show(context, '변경 입고일을 선택해주세요.', type: BannerType.error);
      return;
    }

    if (_selectedType == 'quantity_change') {
      if (widget.itemsForOrder.isEmpty) {
        AppBanner.show(context, '품목 정보가 없습니다.', type: BannerType.error);
        return;
      }
      if (_quantityRows.isEmpty) {
        AppBanner.show(context, '수량 변경 항목을 추가해주세요.', type: BannerType.error);
        return;
      }
      final invalidRow = _quantityRows.any((row) {
        final qty = int.tryParse(row.controller.text.trim());
        return row.itemIndex == null || qty == null || qty <= 0;
      });
      if (invalidRow) {
        AppBanner.show(context, '수량 변경 항목을 모두 입력해주세요.', type: BannerType.error);
        return;
      }
    }

    if (_selectedType == 'price_change') {
      if (widget.itemsForOrder.isEmpty) {
        AppBanner.show(context, '품목 정보가 없습니다.', type: BannerType.error);
        return;
      }
      if (_priceRows.isEmpty) {
        AppBanner.show(context, '단가/합계 변경 항목을 추가해주세요.', type: BannerType.error);
        return;
      }
      final invalidRow = _priceRows.any((row) {
        final value = int.tryParse(row.controller.text.trim());
        return row.itemIndex == null || value == null || value <= 0;
      });
      if (invalidRow) {
        AppBanner.show(context, '단가/합계 변경 항목을 모두 입력해주세요.', type: BannerType.error);
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await widget.onSubmit(
      inquiryType: _selectedType!,
      message: content,
      requestedDeliveryDate: _requestedDeliveryDate,
      quantityRows: _quantityRows,
      priceRows: _priceRows,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentDateLabel = _formatDateText(widget.currentDeliveryDate);
    final requestDateLabel = _formatDateText(widget.requestDate ?? widget.createdAt);
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
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
                '수정 요청',
                style: AppTextStyles.cardTitle(context).copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.all(ResponsiveUtils.spacing(context, 20)),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildErrorBanner(),
              if (_uiErrorMessage != null && _uiErrorMessage!.isNotEmpty)
                SizedBox(height: ResponsiveUtils.spacing(context, 12)),
              _buildSectionTitle('문의 유형 *', Icons.category_outlined),
              SizedBox(height: ResponsiveUtils.spacing(context, 12)),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _buildTypeItems(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedType = value;
                          _ensureRowsForType(value);
                        });
                      },
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                    borderSide: const BorderSide(
                      color: AppColors.border,
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacing(context, 14),
                    vertical: ResponsiveUtils.spacing(context, 12),
                  ),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.spacing(context, 16)),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                  border: Border.all(
                    color: AppColors.border,
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
                        Expanded(
                          child: Text(
                            '발주번호: ${widget.orderNumber}',
                            style: AppTextStyles.inputLabel(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          color: AppColors.textSecondary,
                          size: ResponsiveUtils.iconSize(context, 18),
                        ),
                        SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                        Expanded(
                          child: Text(
                            '업체명: ${widget.vendorName}',
                            style: AppTextStyles.inputLabel(context).copyWith(
                              color: AppColors.gray700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                    Text(
                      '요청일: $requestDateLabel',
                      style: AppTextStyles.tableHeader(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                    Text(
                      '현재 입고요청일: $currentDateLabel',
                      style: AppTextStyles.tableHeader(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacing(context, 6)),
                    Text(
                      '품목:\n$_itemsText',
                      style: AppTextStyles.tableHeader(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacing(context, 20)),
              ..._safeSection(() {
                if (_selectedType != 'delivery_date_change') return const [];
                return [
                  _buildSectionTitle('입고일 변경 *', Icons.calendar_today_rounded),
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                  InkWell(
                    onTap: _isSubmitting
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _requestedDeliveryDate ?? DateTime.now(),
                              firstDate: DateTime(2019),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _requestedDeliveryDate = picked;
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacing(context, 16),
                        vertical: ResponsiveUtils.spacing(context, 14),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        color: Colors.white,
                      ),
                      child: Text(
                        _requestedDeliveryDate != null
                            ? _dateFormat.format(_requestedDeliveryDate!)
                            : '변경 입고일 선택',
                        style: AppTextStyles.inputLabel(context).copyWith(
                          fontWeight: FontWeight.w400,
                          color: _requestedDeliveryDate != null
                              ? AppColors.textPrimary
                              : AppColors.gray400,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 16)),
                ];
              }),
              ..._safeSection(() {
                if (_selectedType != 'quantity_change') return const [];
                return [
                  _buildSectionTitle('수량 변경 항목 *', Icons.playlist_add_outlined),
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                  if (_itemOptions.isEmpty)
                    Text(
                      '품목 정보가 없습니다.',
                      style: AppTextStyles.cardCaption(context).copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  if (_itemOptions.isNotEmpty) ...[
                    ..._quantityRows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      final selectedItem = row.itemIndex != null && row.itemIndex! < widget.itemsForOrder.length
                          ? widget.itemsForOrder[row.itemIndex!]
                          : null;
                      final currentQuantity = selectedItem?['quantity'];
                      final quantityHint = selectedItem == null
                          ? '품목을 선택해주세요'
                          : '현재 수량: ${currentQuantity ?? '-'}';

                      return Padding(
                        padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              value: row.itemIndex,
                              items: _itemOptions,
                              onChanged: _isSubmitting
                                  ? null
                                  : (value) {
                                      setState(() {
                                        row.itemIndex = value;
                                      });
                                    },
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: '품목',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacing(context, 12),
                                  vertical: ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                            TextFormField(
                              controller: row.controller,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: '변경 수량',
                                hintText: quantityHint,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacing(context, 12),
                                  vertical: ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          row.controller.dispose();
                                          _quantityRows.removeAt(index);
                                        });
                                      },
                                icon: const Icon(Icons.remove_circle_outline),
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _quantityRows.add(_QuantityChangeRow());
                                });
                              },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('항목 추가'),
                      ),
                    ),
                  ],
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                ];
              }),
              ..._safeSection(() {
                if (_selectedType != 'price_change') return const [];
                return [
                  _buildSectionTitle('단가/합계 변경 항목 *', Icons.price_change_outlined),
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                  if (_itemOptions.isEmpty)
                    Text(
                      '품목 정보가 없습니다.',
                      style: AppTextStyles.cardCaption(context).copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  if (_itemOptions.isNotEmpty) ...[
                    ..._priceRows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      final selectedItem = row.itemIndex != null && row.itemIndex! < widget.itemsForOrder.length
                          ? widget.itemsForOrder[row.itemIndex!]
                          : null;
                      final unitPrice = selectedItem?['unit_price_value'];
                      final amountValue = selectedItem?['amount_value'];
                      final hintText = row.changeType == 'amount'
                          ? '현재 합계액: ${amountValue ?? '-'}'
                          : '현재 단가: ${unitPrice ?? '-'}';

                      return Padding(
                        padding: EdgeInsets.only(bottom: ResponsiveUtils.spacing(context, 12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              value: row.itemIndex,
                              items: _itemOptions,
                              onChanged: _isSubmitting
                                  ? null
                                  : (value) {
                                      setState(() {
                                        row.itemIndex = value;
                                      });
                                    },
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: '품목',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacing(context, 12),
                                  vertical: ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                            DropdownButtonFormField<String>(
                              value: row.changeType,
                              items: const [
                                DropdownMenuItem(value: 'unit_price', child: Text('단가 변경')),
                                DropdownMenuItem(value: 'amount', child: Text('합계 변경')),
                              ],
                              onChanged: _isSubmitting
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() {
                                        row.changeType = value;
                                      });
                                    },
                              decoration: InputDecoration(
                                labelText: '변경 유형',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacing(context, 12),
                                  vertical: ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.spacing(context, 8)),
                            TextFormField(
                              controller: row.controller,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: '변경 값',
                                hintText: hintText,
                                suffixText: '원',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacing(context, 12),
                                  vertical: ResponsiveUtils.spacing(context, 10),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          row.controller.dispose();
                                          _priceRows.removeAt(index);
                                        });
                                      },
                                icon: const Icon(Icons.remove_circle_outline),
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _priceRows.add(_PriceChangeRow());
                                });
                              },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('항목 추가'),
                      ),
                    ),
                  ],
                  SizedBox(height: ResponsiveUtils.spacing(context, 12)),
                ];
              }),
              _buildSectionTitle('문의 내용 *', Icons.edit_note),
              SizedBox(height: ResponsiveUtils.spacing(context, 12)),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '문의 내용을 자세히 입력해주세요.',
                  hintStyle: AppTextStyles.inputLabel(context).copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.gray400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                    borderSide: const BorderSide(
                      color: AppColors.border,
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
                style: AppTextStyles.tableHeader(context).copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            '취소',
            style: AppTextStyles.inputLabel(context).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
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
          child: _isSubmitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: ResponsiveUtils.iconSize(context, 16),
                      height: ResponsiveUtils.iconSize(context, 16),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacing(context, 8)),
                    Text(
                      '전송 중...',
                      style: AppTextStyles.inputLabel(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  '요청 전송',
                  style: AppTextStyles.inputLabel(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }
}

class _QuantityChangeRow {
  int? itemIndex;
  final TextEditingController controller = TextEditingController();
}

class _PriceChangeRow {
  int? itemIndex;
  String changeType = 'unit_price';
  final TextEditingController controller = TextEditingController();
}

// superadmin 수정 다이얼로그
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
                      style: AppTextStyles.cardTitle(context).copyWith(
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
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
                      ),
                      child: Text(
                        '수정됨',
                        style: AppTextStyles.chipSmall(context, color: Colors.white),
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
                border: Border(top: BorderSide(color: AppColors.border)),
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
                        style: AppTextStyles.sectionSubtitle(context).copyWith(
                          color: AppColors.textSecondary,
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
                              style: AppTextStyles.sectionSubtitle(context).copyWith(
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
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
        border: Border.all(color: AppColors.border),
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
                  style: AppTextStyles.tableHeader(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                Text(
                  value,
                  style: AppTextStyles.sectionSubtitle(context),
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
      style: AppTextStyles.sectionSubtitle(context).copyWith(
        fontWeight: FontWeight.bold,
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
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: const BorderSide(color: AppColors.border),
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
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacing(context, 12)),
          borderSide: const BorderSide(color: AppColors.border),
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
            style: AppTextStyles.sectionSubtitle(context).copyWith(
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
          border: Border.all(color: AppColors.border),
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
                    style: AppTextStyles.tableHeader(context).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    _expectedDeliveryDate != null
                        ? DateFormat('yyyy년 MM월 dd일').format(_expectedDeliveryDate!)
                        : '날짜를 선택해주세요',
                    style: AppTextStyles.sectionSubtitle(context).copyWith(
                      color: _expectedDeliveryDate != null
                          ? AppColors.textPrimary
                          : AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.gray400,
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
          border: Border.all(color: AppColors.border),
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
                    style: AppTextStyles.tableHeader(context).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacing(context, 4)),
                  Text(
                    _revisedDeliveryDate != null
                        ? DateFormat('yyyy년 MM월 dd일').format(_revisedDeliveryDate!)
                        : '날짜를 선택해주세요',
                    style: AppTextStyles.sectionSubtitle(context).copyWith(
                      color: _revisedDeliveryDate != null
                          ? AppColors.textPrimary
                          : AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.gray400,
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
        border: Border.all(color: AppColors.border),
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
                  style: AppTextStyles.chipSmall(context, color: AppColors.primary).copyWith(
                    fontSize: 12,
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
        AppBanner.show(context, '수정이 완료되었습니다.', type: BannerType.success);
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        AppBanner.show(context, '수정 중 오류가 발생했습니다: $e', type: BannerType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}