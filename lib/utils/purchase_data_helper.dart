import '../models/purchase_request.dart';

/// 구매 관련 데이터 처리를 위한 헬퍼 클래스
class PurchaseDataHelper {
  /// 발주번호별로 그룹화하여 PurchaseOrderGroup 리스트 생성
  static Future<List<PurchaseOrderGroup>> groupByOrderNumber({
    required dynamic supabase,
    required List<Map<String, dynamic>> requests,
    bool fetchItems = true,
  }) async {
    final List<PurchaseOrderGroup> groups = [];
    
    // 발주번호별로 그룹화
    final Map<String, Map<String, dynamic>> uniqueOrders = {};
    
    for (final request in requests) {
      final orderNumber = request['purchase_order_number']?.toString();
      if (orderNumber != null && orderNumber.isNotEmpty) {
        uniqueOrders[orderNumber] = request;
      }
    }
    
    // 각 발주번호에 대해 그룹 생성
    for (final entry in uniqueOrders.entries) {
      final purchaseOrderNumber = entry.key;
      final request = entry.value;
      
      try {
        List<PurchaseRequest> items = [];
        
        if (fetchItems) {
          // purchase_request_items 테이블에서 품목 정보 가져오기
          final itemsResponse = await supabase
              .from('purchase_request_items')
              .select()
              .eq('purchase_order_number', purchaseOrderNumber)
              .order('line_number');
          
          final itemsList = List<Map<String, dynamic>>.from(itemsResponse);
          
          if (itemsList.isNotEmpty) {
            // PurchaseRequest 객체로 변환
            items = itemsList.map((itemData) {
              // request 정보와 item 정보 병합
              final mergedData = Map<String, dynamic>.from(request);
              mergedData.addAll(itemData);
              return PurchaseRequest.fromJson(mergedData);
            }).toList();
          }
        }
        
        // 품목 정보가 없으면 request 자체를 사용
        if (items.isEmpty) {
          items.add(PurchaseRequest.fromJson(request));
        }
        
        final totalAmount = items.fold<double>(
          0,
          (sum, item) => sum + item.amountValue,
        );
        
        final firstItem = items.first;
        
        groups.add(
          PurchaseOrderGroup(
            purchaseOrderNumber: purchaseOrderNumber,
            items: items,
            totalAmount: totalAmount,
            vendorName: firstItem.vendorName,
            requesterName: firstItem.requesterName,
            requestDate: firstItem.requestDate,
            paymentCategory: firstItem.paymentCategory,
            middleManagerStatus: firstItem.middleManagerStatus,
            finalManagerStatus: firstItem.finalManagerStatus,
          ),
        );
      } catch (e) {
        // Debug code removed
      }
    }
    
    return groups;
  }
  
  /// 중복 제거 헬퍼 메서드
  static List<Map<String, dynamic>> removeDuplicatesByOrderNumber(
    List<Map<String, dynamic>> requests,
  ) {
    final uniqueOrderNumbers = <String>{};
    final uniqueRequests = <Map<String, dynamic>>[];
    
    for (final request in requests) {
      final orderNumber = request['purchase_order_number']?.toString();
      if (orderNumber != null && 
          orderNumber.isNotEmpty && 
          !uniqueOrderNumbers.contains(orderNumber)) {
        uniqueOrderNumbers.add(orderNumber);
        uniqueRequests.add(request);
      }
    }
    
    return uniqueRequests;
  }
  
  /// 진행 타입 체크 헬퍼
  static bool isAdvanceType(String? progressType) {
    if (progressType == null) return false;
    return progressType.contains('선진행');
  }
  
  /// 카테고리 라벨 변환
  static String getCategoryLabel(String? category) {
    switch (category) {
      case 'raw_material':
        return '원재료';
      case 'consumable':
        return '소모품';
      default:
        return category ?? '';
    }
  }
  
  /// 진행 타입 라벨 변환
  static String getProgressTypeLabel(String? progressType) {
    if (progressType == null) return '일반';
    
    if (progressType.contains('선진행') || 
        progressType.toLowerCase().contains('advance') ||
        progressType.toLowerCase().contains('urgent')) {
      return '선진행';
    }
    
    return '일반';
  }
}