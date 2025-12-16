import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_request.dart';

class PurchaseProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<PurchaseOrderGroup> _pendingOrders = [];
  List<PurchaseOrderGroup> _completedOrders = [];
  bool _isLoading = false;
  String? _error;

  // 역할별 대기 개수
  int _middleManagerPendingCount = 0;
  int _rawMaterialPendingCount = 0;
  int _consumablePendingCount = 0;
  int _totalPendingCount = 0;
  
  // 탭별 카운트 (뱃지 표시용)
  int _purchaseWaitingCount = 0;
  int _receivingWaitingCount = 0;

  List<PurchaseOrderGroup> get pendingOrders => _pendingOrders;
  List<PurchaseOrderGroup> get completedOrders => _completedOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 역할별 대기 개수 getter
  int get middleManagerPendingCount => _middleManagerPendingCount;
  int get rawMaterialPendingCount => _rawMaterialPendingCount;
  int get consumablePendingCount => _consumablePendingCount;
  int get totalPendingCount => _totalPendingCount;
  
  // 탭별 카운트 getter
  int get purchaseWaitingCount => _purchaseWaitingCount;
  int get receivingWaitingCount => _receivingWaitingCount;
  
  // 구매대기/입고대기 탭을 위한 모든 구매요청 데이터 로드
  Future<void> loadAllPurchaseRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 모든 구매요청 가져오기 (승인 상태와 관계없이)
      final response = await _supabase
          .from('purchase_requests')
          .select()
          .order('request_date', ascending: false);
      
      final allRequests = List<Map<String, dynamic>>.from(response);
      
      // 각 발주번호별로 품목 정보 가져오기
      final List<PurchaseOrderGroup> groups = [];
      
      for (final request in allRequests) {
        final purchaseOrderNumber = request['purchase_order_number'];
        if (purchaseOrderNumber == null) continue;
        
        // 해당 발주번호의 모든 품목 가져오기
        final itemsResponse = await _supabase
            .from('purchase_request_items')
            .select()
            .eq('purchase_order_number', purchaseOrderNumber)
            .order('line_number');
        
        final items = (itemsResponse as List).map((itemJson) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(
            itemJson as Map,
          );
          
          // 헤더 정보를 품목 정보와 병합
          final Map<String, dynamic> mergedJson = {
            ...item,
            'request_date': request['request_date'],
            'delivery_request_date': request['delivery_request_date'],
            'middle_manager_status': request['middle_manager_status'],
            'final_manager_status': request['final_manager_status'],
            'payment_category': request['payment_category'],
            'requester_name': request['requester_name'],
            'is_payment_completed': request['is_payment_completed'],
            'is_received': request['is_received'],
            'progress_type': request['progress_type'],
            'vendor_name': request['vendor_name'] ?? item['vendor_name'],
            'project_vendor': request['project_vendor'] ?? item['project_vendor'],
            'sales_order_number': request['sales_order_number'] ?? item['sales_order_number'],
            'project_item': request['project_item'] ?? item['project_item'],
          };
          
          return PurchaseRequest.fromJson(mergedJson);
        }).toList();
        
        if (items.isEmpty) continue;
        
        final totalAmount = items.fold<double>(
          0,
          (sum, item) => sum + item.amountValue,
        );
        
        final headerItem = items.firstWhere(
          (item) => item.lineNumber == 1,
          orElse: () => items.first,
        );
        
        groups.add(
          PurchaseOrderGroup(
            purchaseOrderNumber: purchaseOrderNumber,
            items: items,
            totalAmount: totalAmount,
            vendorName: headerItem.vendorName,
            requesterName: headerItem.requesterName,
            requestDate: DateTime.parse(request['request_date']),
            paymentCategory: request['payment_category'] ?? '',
            middleManagerStatus: request['middle_manager_status'],
            finalManagerStatus: request['final_manager_status'],
            progressType: request['progress_type'],
            isPaymentCompleted: request['is_payment_completed'] ?? false,
            isReceived: request['is_received'] ?? false,
          ),
        );
      }
      
      _pendingOrders = groups;
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 승인 대기 발주 목록 조회
  Future<void> fetchPendingPurchases({
    required Map<String, dynamic>? employee,
  }) async {
    _isLoading = true;
    _error = null;
    // 로딩 중에도 기존 개수는 유지 (0으로 초기화하지 않음)
    notifyListeners();

    try {
      final purchaseRole = employee?['purchase_role'] as List<dynamic>? ?? [];
      List<Map<String, dynamic>> pendingRequests = [];

      if (kDebugMode) {
        print('🔍 [fetchPendingPurchases] 사용자: ${employee?['name']}');
        print('🔍 [fetchPendingPurchases] purchase_role: $purchaseRole');
        print('🔍 [fetchPendingPurchases] app_admin 포함 여부: ${purchaseRole.contains('app_admin')}');
      }

      // app_admin 권한을 명확히 체크
      final bool isAppAdmin = purchaseRole.any((role) => 
        role?.toString().toLowerCase() == 'app_admin' || 
        role == 'app_admin'
      );
      
      if (kDebugMode) {
        print('🔍 [fetchPendingPurchases] isAppAdmin: $isAppAdmin');
      }

      // Step 1: purchase_requests 테이블에서 대기 중인 헤더 정보만 가져오기
      if (isAppAdmin) {
        final response = await _supabase
            .from('purchase_requests')
            .select()
            .or(
              'middle_manager_status.eq.pending,'
              'and(middle_manager_status.eq.approved,final_manager_status.eq.pending)',
            )
            .order('request_date', ascending: false);
        
        // 중복 제거: 발주번호별로 하나씩만 가져오기
        final allRequests = List<Map<String, dynamic>>.from(response);
        final Map<String, Map<String, dynamic>> uniqueRequests = {};
        for (final request in allRequests) {
          final orderNumber = request['purchase_order_number'];
          if (orderNumber != null && !uniqueRequests.containsKey(orderNumber)) {
            uniqueRequests[orderNumber] = request;
          }
        }
        pendingRequests = uniqueRequests.values.toList();
        
        if (kDebugMode) {
          print('✅ [app_admin] 전체 대기 발주 조회 완료: ${pendingRequests.length}건');
          for (final req in pendingRequests) {
            print('  - ${req['purchase_order_number']}: ${req['requester_name']} / ${req['payment_category']}');
          }
        }
      }
      // middle_manager: 1차 승인 대기
      else if (purchaseRole.contains('middle_manager')) {        final response = await _supabase
            .from('purchase_requests')
            .select()
            .eq('middle_manager_status', 'pending')
            .order('request_date', ascending: false);
        
        // 중복 제거: 발주번호별로 하나씩만 가져오기
        final allRequests = List<Map<String, dynamic>>.from(response);
        final Map<String, Map<String, dynamic>> uniqueRequests = {};
        for (final request in allRequests) {
          final orderNumber = request['purchase_order_number'];
          if (orderNumber != null && !uniqueRequests.containsKey(orderNumber)) {
            uniqueRequests[orderNumber] = request;
          }
        }
        pendingRequests = uniqueRequests.values.toList();
        
        if (kDebugMode) {
          print('✅ middle_manager 조회 완료: ${pendingRequests.length}건 (중복 제거)');
        }
      }
      // final_approver + raw_material_manager: '발주'만
      else if (purchaseRole.contains('final_approver') &&
          purchaseRole.contains('raw_material_manager')) {        final response = await _supabase
            .from('purchase_requests')
            .select()
            .eq('middle_manager_status', 'approved')
            .eq('final_manager_status', 'pending')
            .eq('payment_category', '발주')
            .order('request_date', ascending: false);
        
        // 중복 제거: 발주번호별로 하나씩만 가져오기
        final allRequests = List<Map<String, dynamic>>.from(response);
        final Map<String, Map<String, dynamic>> uniqueRequests = {};
        for (final request in allRequests) {
          final orderNumber = request['purchase_order_number'];
          if (orderNumber != null && !uniqueRequests.containsKey(orderNumber)) {
            uniqueRequests[orderNumber] = request;
          }
        }
        pendingRequests = uniqueRequests.values.toList();
        
        if (kDebugMode) {
          print('✅ raw_material 조회 완료: ${pendingRequests.length}건 (중복 제거)');
        }
      }
      // final_approver + consumable_manager: '구매 요청'만
      else if (purchaseRole.contains('final_approver') &&
          purchaseRole.contains('consumable_manager')) {        final response = await _supabase
            .from('purchase_requests')
            .select()
            .eq('middle_manager_status', 'approved')
            .eq('final_manager_status', 'pending')
            .eq('payment_category', '구매 요청')
            .order('request_date', ascending: false);
        
        // 중복 제거: 발주번호별로 하나씩만 가져오기
        final allRequests = List<Map<String, dynamic>>.from(response);
        final Map<String, Map<String, dynamic>> uniqueRequests = {};
        for (final request in allRequests) {
          final orderNumber = request['purchase_order_number'];
          if (orderNumber != null && !uniqueRequests.containsKey(orderNumber)) {
            uniqueRequests[orderNumber] = request;
          }
        }
        pendingRequests = uniqueRequests.values.toList();
        
        
      } else {
        if (kDebugMode) {
          print('⚠️ 발주 승인 권한 없음: $purchaseRole');
        }
      }

      if (kDebugMode) {
      }

      // Step 2: 각 발주번호별로 품목 정보 가져오기
      final List<PurchaseOrderGroup> groups = [];

      for (final request in pendingRequests) {
        final purchaseOrderNumber = request['purchase_order_number'];
        if (purchaseOrderNumber == null) continue;

        // 해당 발주번호의 모든 품목 가져오기
        final itemsResponse = await _supabase
            .from('purchase_request_items')
            .select()
            .eq('purchase_order_number', purchaseOrderNumber)
            .order('line_number');

        final items = (itemsResponse as List).map((itemJson) {
          // 안전한 타입 캐스팅
          final Map<String, dynamic> item = Map<String, dynamic>.from(
            itemJson as Map,
          );
          // 헤더 정보를 품목 정보와 병합 (모든 필드 포함)
          final Map<String, dynamic> mergedJson = {
            ...item,
            'request_date': request['request_date'],
            'delivery_request_date': request['delivery_request_date'],
            'middle_manager_status': request['middle_manager_status'],
            'final_manager_status': request['final_manager_status'],
            'payment_category': request['payment_category'],
            'requester_name': request['requester_name'],
            'is_payment_completed': request['is_payment_completed'],
            'is_received': request['is_received'],
            'vendor_name': request['vendor_name'] ?? item['vendor_name'],
            'project_vendor':
                request['project_vendor'] ?? item['project_vendor'],
            'sales_order_number':
                request['sales_order_number'] ?? item['sales_order_number'],
            'project_item': request['project_item'] ?? item['project_item'],
          };

          if (kDebugMode) {
          }

          return PurchaseRequest.fromJson(mergedJson);
        }).toList();

        if (items.isEmpty) continue;

        final totalAmount = items.fold<double>(
          0,
          (sum, item) => sum + item.amountValue,
        );

        // 라인넘버로 정렬된 items에서 헤더 아이템(line_number = 1) 찾기
        final headerItem = items.firstWhere(
          (item) => item.lineNumber == 1,
          orElse: () => items.first,
        );

        if (kDebugMode) {
          print(
            '  - 헤더 아이템: ${headerItem.itemName} (라인넘버: ${headerItem.lineNumber})',
          );
        }

        groups.add(
          PurchaseOrderGroup(
            purchaseOrderNumber: purchaseOrderNumber,
            items: items,
            totalAmount: totalAmount,
            vendorName: headerItem.vendorName,
            requesterName: headerItem.requesterName,
            requestDate: DateTime.parse(request['request_date']),
            paymentCategory: request['payment_category'] ?? '',
            middleManagerStatus: request['middle_manager_status'],
            finalManagerStatus: request['final_manager_status'],
            progressType: request['progress_type'],
          ),
        );
      }

      _pendingOrders = groups;
      // 역할별 대기 개수 계산 (await 추가)
      await _calculatePendingCounts(purchaseRole, isAppAdmin: isAppAdmin);
      
      // 탭별 카운트 계산
      await _calculateTabCounts(employee, isAppAdmin: isAppAdmin);
    } catch (e) {
      _error = e.toString();    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 중간 승인
  Future<bool> approveMiddle(String purchaseOrderNumber) async {
    try {
      // 발주 정보 가져오기 (알림용)
      final orderInfo = _pendingOrders.firstWhere(
        (order) => order.purchaseOrderNumber == purchaseOrderNumber,
        orElse: () => _pendingOrders.first,
      );

      await _supabase
          .from('purchase_requests')
          .update({'middle_manager_status': 'approved'})
          .eq('purchase_order_number', purchaseOrderNumber);

      // 알림 전송 (최종 승인자들에게)
      try {
        await _sendPurchaseApprovalNotification(
          purchaseOrderNumber: purchaseOrderNumber,
          requesterName: orderInfo.requesterName,
          paymentCategory: orderInfo.paymentCategory ?? '',
          status: 'middle_approved',
          isMiddleManager: true,
        );
      } catch (e) {
        
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 최종 승인
  Future<bool> approveFinal(String purchaseOrderNumber) async {
    try {
      // 발주 정보 가져오기 (알림용)
      final orderInfo = _pendingOrders.firstWhere(
        (order) => order.purchaseOrderNumber == purchaseOrderNumber,
        orElse: () => _pendingOrders.first,
      );

      await _supabase
          .from('purchase_requests')
          .update({
            'final_manager_status': 'approved',
            'final_manager_approved_at': DateTime.now().toIso8601String(),
          })
          .eq('purchase_order_number', purchaseOrderNumber);

      // 알림 전송 (신청자에게)
      try {
        await _sendPurchaseApprovalNotification(
          purchaseOrderNumber: purchaseOrderNumber,
          requesterName: orderInfo.requesterName,
          paymentCategory: orderInfo.paymentCategory ?? '',
          status: 'final_approved',
          isMiddleManager: false,
        );
      } catch (e) {
        
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 반려
  Future<bool> rejectPurchase(
    String purchaseOrderNumber, {
    required bool isMiddleManager,
    required String reason,
  }) async {
    try {
      // 발주 정보 가져오기 (알림용)
      final orderInfo = _pendingOrders.firstWhere(
        (order) => order.purchaseOrderNumber == purchaseOrderNumber,
        orElse: () => _pendingOrders.first,
      );

      Map<String, dynamic> updateData;

      if (isMiddleManager) {
        updateData = {
          'middle_manager_status': 'rejected',
          'middle_manager_rejected_at': DateTime.now().toIso8601String(),
          'middle_manager_rejection_reason': reason,
        };
      } else {
        // payment_category에 따라 적절한 컬럼 업데이트
        if (orderInfo.paymentCategory == '원자재') {
          updateData = {
            'raw_material_manager_status': 'rejected',
            'raw_material_manager_rejected_at': DateTime.now()
                .toIso8601String(),
            'raw_material_manager_rejection_reason': reason,
          };
        } else {
          updateData = {
            'consumable_manager_status': 'rejected',
            'consumable_manager_rejected_at': DateTime.now().toIso8601String(),
            'consumable_manager_rejection_reason': reason,
          };
        }
      }

      await _supabase
          .from('purchase_requests')
          .update(updateData)
          .eq('purchase_order_number', purchaseOrderNumber);

      // 알림 전송 (신청자에게)
      try {
        await _sendPurchaseApprovalNotification(
          purchaseOrderNumber: purchaseOrderNumber,
          requesterName: orderInfo.requesterName,
          paymentCategory: orderInfo.paymentCategory ?? '',
          status: 'rejected',
          isMiddleManager: isMiddleManager,
          rejectionReason: reason,
        );
      } catch (e) {
        
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 역할별 대기 개수 계산
  Future<void> _calculatePendingCounts(List<dynamic> purchaseRole, {bool isAppAdmin = false}) async {
    try {
      // 병렬로 모든 쿼리 실행
      final results = await Future.wait([
        // 1차 승인 대기 개수 (middle_manager)
        _supabase
            .from('purchase_requests')
            .select('purchase_order_number')
            .eq('middle_manager_status', 'pending'),

        // 최종 승인 대기 - 발주 (raw_material_manager)
        _supabase
            .from('purchase_requests')
            .select('purchase_order_number')
            .eq('middle_manager_status', 'approved')
            .eq('final_manager_status', 'pending')
            .eq('payment_category', '발주'),

        // 최종 승인 대기 - 구매 요청 (consumable_manager)
        _supabase
            .from('purchase_requests')
            .select('purchase_order_number')
            .eq('middle_manager_status', 'approved')
            .eq('final_manager_status', 'pending')
            .eq('payment_category', '구매 요청'),
      ]);

      // 중복 제거를 위해 Set 사용
      final middleSet = Set<String>.from(
        (results[0] as List)
            .map((r) => r['purchase_order_number'])
            .where((p) => p != null),
      );
      final rawSet = Set<String>.from(
        (results[1] as List)
            .map((r) => r['purchase_order_number'])
            .where((p) => p != null),
      );
      final consumableSet = Set<String>.from(
        (results[2] as List)
            .map((r) => r['purchase_order_number'])
            .where((p) => p != null),
      );

      _middleManagerPendingCount = middleSet.length;
      _rawMaterialPendingCount = rawSet.length;
      _consumablePendingCount = consumableSet.length;

      // app_admin은 모든 대기 개수
      if (isAppAdmin) {
        _totalPendingCount =
            _middleManagerPendingCount +
            _rawMaterialPendingCount +
            _consumablePendingCount;
      } else {
        _totalPendingCount = 0;
        if (purchaseRole.contains('middle_manager')) {
          _totalPendingCount += _middleManagerPendingCount;
        }
        if (purchaseRole.contains('final_approver')) {
          if (purchaseRole.contains('raw_material_manager')) {
            _totalPendingCount += _rawMaterialPendingCount;
          }
          if (purchaseRole.contains('consumable_manager')) {
            _totalPendingCount += _consumablePendingCount;
          }
        }
      }
      // UI 업데이트를 위해 notifyListeners 호출
      notifyListeners();
    } catch (e) {
      // 오류 발생 시 무시
    }
  }
  
  // 탭별 카운트 계산 (구매대기, 입고대기)
  Future<void> _calculateTabCounts(Map<String, dynamic>? employee, {bool isAppAdmin = false}) async {
    try {
      final purchaseRole = employee?['purchase_role'] as List<dynamic>? ?? [];
      final userName = employee?['name'] ?? '';
      final isLeadBuyer = purchaseRole.contains('lead buyer');
      final isMiddleManager = purchaseRole.contains('middle_manager');
      final isFinalApprover = purchaseRole.contains('raw_material_manager') || 
                              purchaseRole.contains('consumable_manager');
      final isCeo = purchaseRole.contains('ceo');
      
      // 구매대기 카운트 (선진행 + 일반&최종승인)
      final purchaseResponse = await _supabase
          .from('purchase_requests')
          .select('*, purchase_request_items(*)')
          .eq('payment_category', '구매 요청')
          .eq('is_payment_completed', false);
      
      final purchasePurchases = (purchaseResponse as List<dynamic>).where((purchase) {
        final progressType = purchase['progress_type'] ?? '';
        final finalStatus = purchase['final_manager_status'] ?? '';
        
        // 선진행은 무조건 포함
        if (progressType.toString().contains('선진행')) return true;
        // 일반은 최종승인 완료된 것만
        if (progressType.toString().contains('일반') && finalStatus == 'approved') return true;
        
        return false;
      }).toList();
      
      // 권한에 따른 필터링
      if (!isAppAdmin && !isLeadBuyer) {
        _purchaseWaitingCount = purchasePurchases.where((p) => 
          p['requester_name'] == userName
        ).length;
      } else {
        _purchaseWaitingCount = purchasePurchases.length;
      }
      
      // 입고대기 카운트 (선진행 + 최종승인)
      final receivingResponse = await _supabase
          .from('purchase_requests')
          .select('*, purchase_request_items(*)')
          .eq('is_received', false);
      
      final receivingPurchases = (receivingResponse as List<dynamic>).where((purchase) {
        final progressType = purchase['progress_type'] ?? '';
        final finalStatus = purchase['final_manager_status'] ?? '';
        
        // 선진행은 무조건 포함
        if (progressType.toString().contains('선진행')) return true;
        // 최종승인 완료된 것 포함
        if (finalStatus == 'approved') return true;
        
        return false;
      }).toList();
      
      // 권한에 따른 필터링
      if (!isAppAdmin && !isLeadBuyer && !isMiddleManager && !isFinalApprover && !isCeo) {
        _receivingWaitingCount = receivingPurchases.where((p) => 
          p['requester_name'] == userName
        ).length;
      } else {
        _receivingWaitingCount = receivingPurchases.length;
      }      
      notifyListeners();
    } catch (e) {      _purchaseWaitingCount = 0;
      _receivingWaitingCount = 0;
    }
  }

  // 금일 처리완료 발주 목록 조회
  Future<void> fetchCompletedPurchases({
    required Map<String, dynamic>? employee,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final purchaseRole = employee?['purchase_role'] as List<dynamic>? ?? [];
      
      // app_admin 권한을 명확히 체크
      final bool isAppAdmin = purchaseRole.any((role) => 
        role?.toString().toLowerCase() == 'app_admin' || 
        role == 'app_admin'
      );

      // 날짜 범위 설정 (한국 시간 기준)
      final now = DateTime.now();
      final DateTime filterStartDate;
      final DateTime filterEndDate;
      
      if (startDate != null && endDate != null) {
        // 사용자 지정 날짜 범위
        filterStartDate = DateTime(startDate.year, startDate.month, startDate.day);
        filterEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else {
        // 기본: 최근 1개월
        filterEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        filterStartDate = DateTime(now.year, now.month - 1, now.day);
      }
      
      List<Map<String, dynamic>> completedRequests = [];

      // 성능 최적화: 조인 쿼리로 한 번에 품목 정보까지 가져오기
      if (isAppAdmin) {
        // app_admin은 모든 승인/반려 항목 조회 (품목 정보 포함)
        if (kDebugMode) {
          print('✅ [app_admin] 처리완료 발주 조회 시작');
        }
        final response = await _supabase
            .from('purchase_requests')
            .select('*, purchase_request_items(*)')
            .or(
              'middle_manager_status.eq.approved,middle_manager_status.eq.rejected,final_manager_status.eq.approved,final_manager_status.eq.rejected',
            )
            .gte('request_date', filterStartDate.toIso8601String())
            .lte('request_date', filterEndDate.toIso8601String())
            .order('request_date', ascending: false);
        completedRequests = List<Map<String, dynamic>>.from(response);
        
        if (kDebugMode) {
          print('✅ [app_admin] 처리완료 발주 조회: ${completedRequests.length}건');
        }
      } else if (purchaseRole.contains('middle_manager')) {
        // 1차 승인자가 처리한 항목 (품목 정보 포함)
        final response = await _supabase
            .from('purchase_requests')
            .select('*, purchase_request_items(*)')
            .or(
              'middle_manager_status.eq.approved,middle_manager_status.eq.rejected',
            )
            .gte('request_date', filterStartDate.toIso8601String())
            .lte('request_date', filterEndDate.toIso8601String())
            .order('request_date', ascending: false);
        completedRequests = List<Map<String, dynamic>>.from(response);
      } else if (purchaseRole.contains('final_approver')) {
        // 최종 승인자가 처리한 항목 (품목 정보 포함)
        List<String> categories = [];
        if (purchaseRole.contains('raw_material_manager')) {
          categories.add('발주');
        }
        if (purchaseRole.contains('consumable_manager')) {
          categories.add('구매 요청');
        }

        if (categories.isNotEmpty) {
          final response = await _supabase
              .from('purchase_requests')
              .select('*, purchase_request_items(*)')
              .inFilter('payment_category', categories)
              .or(
                'final_manager_status.eq.approved,final_manager_status.eq.rejected',
              )
              .gte('request_date', filterStartDate.toIso8601String())
              .lte('request_date', filterEndDate.toIso8601String())
              .order('request_date', ascending: false);
          completedRequests = List<Map<String, dynamic>>.from(response);
        }
      }

      // 성능 최적화: 이미 조인으로 가져온 데이터를 바로 그룹화
      final Map<String, List<Map<String, dynamic>>> groupedData = {};
      
      for (final request in completedRequests) {
        final orderNumber = request['purchase_order_number'];
        if (orderNumber == null) continue;
        
        final items = request['purchase_request_items'] as List<dynamic>? ?? [];
        if (items.isNotEmpty) {
          groupedData[orderNumber] = items.cast<Map<String, dynamic>>();
        }
      }

      // 발주번호별로 PurchaseOrderGroup 생성
      final List<PurchaseOrderGroup> groups = [];

      for (final entry in groupedData.entries) {
        final orderNumber = entry.key;
        final items = entry.value;
        
        // 헤더 정보는 첫 번째 요청에서 가져오기
        final headerRequest = completedRequests.firstWhere(
          (req) => req['purchase_order_number'] == orderNumber,
        );

        // 품목 데이터를 PurchaseRequest 객체로 변환
        final purchaseItems = items.map((itemJson) {
          final Map<String, dynamic> mergedJson = {
            ...itemJson,
            'request_date': headerRequest['request_date'],
            'delivery_request_date': headerRequest['delivery_request_date'],
            'middle_manager_status': headerRequest['middle_manager_status'],
            'final_manager_status': headerRequest['final_manager_status'],
            'payment_category': headerRequest['payment_category'],
            'requester_name': headerRequest['requester_name'],
            'is_payment_completed': headerRequest['is_payment_completed'],
            'is_received': headerRequest['is_received'],
            'vendor_name': headerRequest['vendor_name'] ?? itemJson['vendor_name'],
            'project_vendor': headerRequest['project_vendor'] ?? itemJson['project_vendor'],
            'sales_order_number': headerRequest['sales_order_number'] ?? itemJson['sales_order_number'],
            'project_item': headerRequest['project_item'] ?? itemJson['project_item'],
          };
          return PurchaseRequest.fromJson(mergedJson);
        }).toList();

        if (purchaseItems.isEmpty) continue;

        final totalAmount = purchaseItems.fold<double>(
          0,
          (sum, item) => sum + item.amountValue,
        );

        final headerItem = purchaseItems.firstWhere(
          (item) => item.lineNumber == 1,
          orElse: () => purchaseItems.first,
        );

        groups.add(
          PurchaseOrderGroup(
            purchaseOrderNumber: orderNumber,
            items: purchaseItems,
            totalAmount: totalAmount,
            vendorName: headerItem.vendorName,
            requesterName: headerItem.requesterName,
            requestDate: DateTime.parse(headerRequest['request_date']),
            paymentCategory: headerRequest['payment_category'] ?? '',
            middleManagerStatus: headerRequest['middle_manager_status'],
            finalManagerStatus: headerRequest['final_manager_status'],
            progressType: headerRequest['progress_type'],
          ),
        );
      }

      _completedOrders = groups;

      if (kDebugMode) {
      }
    } catch (e) {
      _error = e.toString();    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 단일 발주서의 상세 아이템 조회
  Future<List<PurchaseRequest>> fetchOrderDetails(
    String purchaseOrderNumber,
  ) async {
    try {
      final response = await _supabase
          .from('purchase_request_items')
          .select()
          .eq('purchase_order_number', purchaseOrderNumber)
          .order('line_number');

      final items = (response as List)
          .map((json) => PurchaseRequest.fromJson(json))
          .toList();

      return items;
    } catch (e) {
      return [];
    }
  }

  // 발주 승인 알림 전송
  Future<void> _sendPurchaseApprovalNotification({
    required String purchaseOrderNumber,
    required String requesterName,
    required String paymentCategory,
    required String status,
    required bool isMiddleManager,
    String? rejectionReason,
  }) async {
    try {
      // status에 따른 알림 대상 및 메시지 결정
      String title = '';
      String body = '';
      List<String> targetRoles = [];

      if (status == 'middle_approved') {
        // 1차 승인 완료 -> 최종 승인자들에게 알림
        title = '🔔 발주 최종 승인 요청';
        body =
            '$requesterName님의 $paymentCategory 발주($purchaseOrderNumber)가 최종 승인 대기중입니다.';

        if (paymentCategory == '발주') {
          targetRoles = ['raw_material_manager'];
        } else {
          targetRoles = ['consumable_manager'];
        }
      } else if (status == 'final_approved') {
        // 최종 승인 완료 -> 신청자에게 알림
        title = '✅ 발주 승인 완료';
        body = '$purchaseOrderNumber 발주가 최종 승인되었습니다. 발주 진행을 해주세요.';
        // 신청자에게 직접 알림 (targetRoles 비워둠)
      } else if (status == 'rejected') {
        // 반려 -> 신청자에게 알림
        title = '❌ 발주 반려';
        final stage = isMiddleManager ? '1차' : '최종';
        body =
            '$purchaseOrderNumber 발주가 $stage 승인에서 반려되었습니다.\n사유: $rejectionReason';
        // 신청자에게 직접 알림 (targetRoles 비워둠)
      }

      // Supabase Edge Function 호출하여 알림 전송
      if (targetRoles.isNotEmpty) {
        // 역할 기반 알림 (최종 승인자들에게)
        for (final role in targetRoles) {
          await _sendNotificationToRole(role, title, body, purchaseOrderNumber);
        }
      } else {
        // 신청자에게 직접 알림
        await _sendNotificationToRequester(
          requesterName,
          title,
          body,
          purchaseOrderNumber,
        );
      }    } catch (e) {      // 알림 실패해도 승인 프로세스는 계속 진행
    }
  }

  // 역할 기반 알림 전송
  Future<void> _sendNotificationToRole(
    String role,
    String title,
    String body,
    String purchaseOrderNumber,
  ) async {
    try {
      // purchase_role에 해당 role을 가진 사용자들 조회
      final users = await _supabase
          .from('employees')
          .select('fcm_token')
          .contains('purchase_role', [role])
          .not('fcm_token', 'is', null);

      for (final user in users) {
        final fcmToken = user['fcm_token'];
        if (fcmToken != null && fcmToken.toString().isNotEmpty) {
          // FCM 전송 로직 (Edge Function 호출)
          await _sendFcmNotification(fcmToken, title, body, {
            'type': 'purchase_approval',
            'purchase_order_number': purchaseOrderNumber,
          });
        }
      }
    } catch (e) {
      // 오류 발생 시 무시
    }
  }

  // 신청자에게 알림 전송
  Future<void> _sendNotificationToRequester(
    String requesterName,
    String title,
    String body,
    String purchaseOrderNumber,
  ) async {
    try {
      // 신청자 정보 조회
      final user = await _supabase
          .from('employees')
          .select('fcm_token')
          .eq('name', requesterName)
          .maybeSingle();

      if (user != null) {
        final fcmToken = user['fcm_token'];
        if (fcmToken != null && fcmToken.toString().isNotEmpty) {
          // FCM 전송 로직 (Edge Function 호출)
          await _sendFcmNotification(fcmToken, title, body, {
            'type': 'purchase_result',
            'purchase_order_number': purchaseOrderNumber,
          });
        }
      }
    } catch (e) {
      // 오류 발생 시 무시
    }
  }

  // FCM 알림 전송 (Edge Function 호출)
  Future<void> _sendFcmNotification(
    String fcmToken,
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    try {
      await _supabase.functions.invoke(
        'send_fcm_notification',
        body: {'token': fcmToken, 'title': title, 'body': body, 'data': data},
      );
    } catch (e) {
      // 오류 발생 시 무시
    }
  }

  // 새 발주 요청 알림 전송 (1차 승인자들에게)
  Future<void> sendNewPurchaseRequestNotification({
    required String purchaseOrderNumber,
    required String requesterName,
    required String paymentCategory,
    required double totalAmount,
  }) async {
    try {
      final title = '🆕 새 발주 승인 요청';
      final formattedAmount = totalAmount.toStringAsFixed(0);
      final body =
          '$requesterName님이 $paymentCategory 발주($purchaseOrderNumber)를 요청했습니다.\n금액: $formattedAmount원';

      // middle_manager 역할을 가진 사용자들에게 알림
      await _sendNotificationToRole(
        'middle_manager',
        title,
        body,
        purchaseOrderNumber,
      );

      // app_admin에게도 알림
      await _sendNotificationToRole(
        'app_admin',
        title,
        body,
        purchaseOrderNumber,
      );    } catch (e) {
      // 오류 발생 시 무시
    }
  }
}
