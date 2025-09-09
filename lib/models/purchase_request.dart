class PurchaseRequest {
  final int id;
  final String? purchaseOrderNumber;
  final DateTime requestDate;
  final DateTime deliveryRequestDate;
  final String progressType;
  final bool isPaymentCompleted;
  final String paymentCategory;
  final String currency;
  final String requestType;
  final String vendorName;
  final String vendorPaymentSchedule;
  final String requesterName;
  final String itemName;
  final String specification;
  final int quantity;
  final double unitPriceValue;
  final double amountValue;
  final String? remark;
  final String? projectVendor;
  final String? salesOrderNumber;
  final String? projectItem;
  final int lineNumber;
  final String? contactName;
  final String? middleManagerStatus;
  final String? finalManagerStatus;
  final DateTime? paymentCompletedAt;
  final bool isReceived;
  final DateTime? receivedAt;
  final DateTime? finalManagerApprovedAt;
  final bool? isPoDownload;
  final String? link;

  PurchaseRequest({
    required this.id,
    this.purchaseOrderNumber,
    required this.requestDate,
    required this.deliveryRequestDate,
    required this.progressType,
    required this.isPaymentCompleted,
    required this.paymentCategory,
    required this.currency,
    required this.requestType,
    required this.vendorName,
    required this.vendorPaymentSchedule,
    required this.requesterName,
    required this.itemName,
    required this.specification,
    required this.quantity,
    required this.unitPriceValue,
    required this.amountValue,
    this.remark,
    this.projectVendor,
    this.salesOrderNumber,
    this.projectItem,
    required this.lineNumber,
    this.contactName,
    this.middleManagerStatus,
    this.finalManagerStatus,
    this.paymentCompletedAt,
    required this.isReceived,
    this.receivedAt,
    this.finalManagerApprovedAt,
    this.isPoDownload,
    this.link,
  });

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    return PurchaseRequest(
      id: json['id'] ?? 0,
      purchaseOrderNumber: json['purchase_order_number']?.toString(),
      requestDate: json['request_date'] != null
          ? DateTime.parse(json['request_date'])
          : DateTime.now(),
      deliveryRequestDate: json['delivery_request_date'] != null
          ? DateTime.parse(json['delivery_request_date'])
          : DateTime.now(),
      progressType: json['progress_type']?.toString() ?? '',
      isPaymentCompleted: json['is_payment_completed'] ?? false,
      paymentCategory: json['payment_category']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'KRW',
      requestType: json['request_type']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      vendorPaymentSchedule: json['vendor_payment_schedule']?.toString() ?? '',
      requesterName: json['requester_name']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      quantity: json['quantity'] ?? 0,
      unitPriceValue: json['unit_price_value'] != null
          ? (json['unit_price_value'] is String
                ? double.tryParse(json['unit_price_value']) ?? 0.0
                : (json['unit_price_value'] as num).toDouble())
          : 0.0,
      amountValue: json['amount_value'] != null
          ? (json['amount_value'] is String
                ? double.tryParse(json['amount_value']) ?? 0.0
                : (json['amount_value'] as num).toDouble())
          : 0.0,
      remark: json['remark']?.toString(),
      projectVendor: json['project_vendor']?.toString(),
      salesOrderNumber: json['sales_order_number']?.toString(),
      projectItem: json['project_item']?.toString(),
      lineNumber: json['line_number'] ?? 1,
      contactName: json['contact_name']?.toString(),
      middleManagerStatus: json['middle_manager_status']?.toString(),
      finalManagerStatus: json['final_manager_status']?.toString(),
      paymentCompletedAt: json['payment_completed_at'] != null
          ? DateTime.parse(json['payment_completed_at'])
          : null,
      isReceived: json['is_received'] ?? false,
      receivedAt: json['received_at'] != null
          ? DateTime.parse(json['received_at'])
          : null,
      finalManagerApprovedAt: json['final_manager_approved_at'] != null
          ? DateTime.parse(json['final_manager_approved_at'])
          : null,
      isPoDownload: json['is_po_download'],
      link: json['link']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_order_number': purchaseOrderNumber,
      'request_date': requestDate.toIso8601String(),
      'delivery_request_date': deliveryRequestDate.toIso8601String(),
      'progress_type': progressType,
      'is_payment_completed': isPaymentCompleted,
      'payment_category': paymentCategory,
      'currency': currency,
      'request_type': requestType,
      'vendor_name': vendorName,
      'vendor_payment_schedule': vendorPaymentSchedule,
      'requester_name': requesterName,
      'item_name': itemName,
      'specification': specification,
      'quantity': quantity,
      'unit_price_value': unitPriceValue,
      'amount_value': amountValue,
      'remark': remark,
      'project_vendor': projectVendor,
      'sales_order_number': salesOrderNumber,
      'project_item': projectItem,
      'line_number': lineNumber,
      'contact_name': contactName,
      'middle_manager_status': middleManagerStatus,
      'final_manager_status': finalManagerStatus,
      'payment_completed_at': paymentCompletedAt?.toIso8601String(),
      'is_received': isReceived,
      'received_at': receivedAt?.toIso8601String(),
      'final_manager_approved_at': finalManagerApprovedAt?.toIso8601String(),
      'is_po_download': isPoDownload,
      'link': link,
    };
  }
}

// 발주서 그룹 (동일한 purchase_order_number를 가진 아이템들)
class PurchaseOrderGroup {
  final String purchaseOrderNumber;
  final List<PurchaseRequest> items;
  final double totalAmount;
  final String vendorName;
  final String requesterName;
  final DateTime requestDate;
  final String paymentCategory;
  final String? middleManagerStatus;
  final String? finalManagerStatus;

  PurchaseOrderGroup({
    required this.purchaseOrderNumber,
    required this.items,
    required this.totalAmount,
    required this.vendorName,
    required this.requesterName,
    required this.requestDate,
    required this.paymentCategory,
    this.middleManagerStatus,
    this.finalManagerStatus,
  });

  // 헤더 아이템 (line_number가 1인 항목)
  PurchaseRequest get headerItem {
    try {
      return items.firstWhere((item) => item.lineNumber == 1);
    } catch (e) {
      // line_number 1이 없으면 첫 번째 아이템 반환
      return items.first;
    }
  }

  // 추가 아이템 개수 (헤더 제외)
  int get additionalItemCount => items.length - 1;
}
