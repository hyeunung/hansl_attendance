import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/user_role_helper.dart';

class SupportAttachment {
  final String url;
  final String name;
  final int size;
  final String path;

  const SupportAttachment({
    required this.url,
    required this.name,
    required this.size,
    required this.path,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      url: (json['url'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      size: (json['size'] is int)
          ? (json['size'] as int)
          : int.tryParse((json['size'] ?? '0').toString()) ?? 0,
      path: (json['path'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'size': size,
        'path': path,
      };
}

class SupportInquiryMessage {
  final int id;
  final int inquiryId;
  final String senderRole; // user | admin | system
  final String senderEmail;
  final String message;
  final List<SupportAttachment> attachments;
  final DateTime createdAt;

  const SupportInquiryMessage({
    required this.id,
    required this.inquiryId,
    required this.senderRole,
    required this.senderEmail,
    required this.message,
    required this.attachments,
    required this.createdAt,
  });

  static List<SupportAttachment> _parseAttachments(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .map(SupportAttachment.fromJson)
          .toList();
    }
    return const [];
  }

  factory SupportInquiryMessage.fromJson(Map<String, dynamic> json) {
    return SupportInquiryMessage(
      id: (json['id'] as num).toInt(),
      inquiryId: (json['inquiry_id'] as num).toInt(),
      senderRole: (json['sender_role'] ?? '').toString(),
      senderEmail: (json['sender_email'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      attachments: _parseAttachments(json['attachments']),
      createdAt: DateTime.parse((json['created_at'] ?? '').toString()),
    );
  }
}

/// 문의하기 서비스
/// - 일반 직원: 문의 작성 및 본인 문의 조회
/// - superadmin: 모든 문의 조회 및 답변/상태 변경
class InquiryService {
  
  final _supabase = Supabase.instance.client;
  static const String _attachmentsBucket = 'support-attachments';

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// 사용자 권한 확인 (superadmin 여부)
  Future<bool> isAppAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) return false;

      final response = await _supabase
          .from('employees')
          .select('roles')
          .eq('email', user.email!)
          .maybeSingle();

      if (response == null) return false;
      final roles = UserRoleHelper.getRoles(response);

      return UserRoleHelper.isAppAdmin(roles);
    } catch (e) {
      // Debug code removed
      return false;
    }
  }

  /// 문의 생성 (일반 직원만 가능)
  Future<Map<String, dynamic>> createInquiry({
    required String inquiryType,
    required String subject,
    required String message,
    required String userName,
    required String userEmail,
    int? purchaseRequestId,
    String? purchaseOrderNumber,
    String? purchaseInfo,
    String? requesterId,
    List<SupportAttachment>? attachments,
    Map<String, dynamic>? inquiryPayload,
    bool includeInitialMessage = false,
  }) async {
    try {
      // superadmin은 문의 생성 불가
      if (await isAppAdmin()) {
        return {
          'success': false,
          'error': '관리자는 문의를 작성할 수 없습니다.',
          'message': '관리자는 문의 내역 확인 및 답변만 가능합니다.',
        };
      }

      // Debug code removed

      final user = _supabase.auth.currentUser;

      // 앱에서 전달되는 문의 유형을 DB 유형으로 매핑
      String dbInquiryType = inquiryType;
      switch (inquiryType) {
        case '오류':
          dbInquiryType = 'bug';
          break;
        case '수정 요청':
          dbInquiryType = 'modify';
          break;
        case '삭제 요청':
          dbInquiryType = 'delete';
          break;
        case '기타':
        case '연차':
        case '근태':
          dbInquiryType = 'other';
          break;
      }

      final data = {
        'user_id': user?.id,
        'user_email': userEmail,
        'user_name': userName,
        'inquiry_type': dbInquiryType,
        'subject': subject,
        'message': message,
        'status': 'open',
        'purchase_request_id': purchaseRequestId,
        'purchase_order_number': purchaseOrderNumber,
        'purchase_info': purchaseInfo,
        'requester_id': requesterId,
        'attachments': (attachments ?? const [])
            .map((a) => a.toJson())
            .toList(growable: false),
        'inquiry_payload': inquiryPayload,
      };

      final response = await _supabase
          .from('support_inquires')
          .insert(data)
          .select()
          .single();

      if (includeInitialMessage) {
        // 첫 메시지(사용자) 기록: 대화 로그 시작
        final inquiryId = (response['id'] as num?)?.toInt();
        if (inquiryId == null) {
          return {
            'success': false,
            'error': '문의 ID를 확인할 수 없습니다.',
            'message': '문의 등록에 실패했습니다.\n잠시 후 다시 시도해주세요.',
          };
        }

        final senderEmail = _supabase.auth.currentUser?.email ?? userEmail;
        try {
          await _supabase.from('support_inquiry_messages').insert({
            'inquiry_id': inquiryId,
            'sender_role': 'user',
            'sender_email': senderEmail,
            'message': message,
            'attachments': (attachments ?? const [])
                .map((a) => a.toJson())
                .toList(growable: false),
          });
        } catch (e) {
          // 메시지 기록 실패 시(문의는 생성됨) 에러로 처리
          return {
            'success': false,
            'error': e.toString(),
            'message': '문의는 등록됐지만 대화 저장에 실패했습니다.\n잠시 후 다시 시도해주세요.',
          };
        }
      }

      return {
        'success': true,
        'data': response,
        'message': '문의가 성공적으로 등록되었습니다.\n관리자가 확인 후 답변드리겠습니다.',
      };
    } catch (e) {
      // Debug code removed
      return {
        'success': false,
        'error': e.toString(),
        'message': '문의 등록에 실패했습니다.\n잠시 후 다시 시도해주세요.',
      };
    }
  }

  /// 첨부 이미지 업로드 (support-attachments 버킷)
  Future<Map<String, dynamic>> uploadAttachment({
    required String originalFileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.id.isEmpty) {
        return {
          'success': false,
          'error': '로그인이 필요합니다.',
        };
      }

      final ext = originalFileName.contains('.')
          ? originalFileName.split('.').last.toLowerCase()
          : 'jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomStr = _randomString(6);
      final fileName = 'support_${timestamp}_$randomStr.$ext';
      final filePath = 'inquiries/${user.id}/$fileName';

      await _supabase.storage.from(_attachmentsBucket).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: false,
        ),
      );

      final publicUrl =
          _supabase.storage.from(_attachmentsBucket).getPublicUrl(filePath);

      return {
        'success': true,
        'data': SupportAttachment(
          url: publicUrl,
          name: originalFileName,
          size: bytes.length,
          path: filePath,
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deleteAttachment(String path) async {
    try {
      await _supabase.storage.from(_attachmentsBucket).remove([path]);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 문의 메시지 목록 조회
  Future<Map<String, dynamic>> getInquiryMessages(int inquiryId) async {
    try {
      final response = await _supabase
          .from('support_inquiry_messages')
          .select('*')
          .eq('inquiry_id', inquiryId)
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(response as List);
      final messages = list.map(SupportInquiryMessage.fromJson).toList();

      return {
        'success': true,
        'data': messages,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'data': <SupportInquiryMessage>[]};
    }
  }

  /// 문의 메시지 전송 (user/admin)
  Future<Map<String, dynamic>> sendInquiryMessage({
    required int inquiryId,
    required String senderRole, // user | admin
    required String message,
    List<SupportAttachment>? attachments,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final senderEmail = user?.email ?? '';
      if (senderEmail.isEmpty) {
        return {'success': false, 'error': '사용자 이메일을 확인할 수 없습니다.'};
      }

      await _supabase.from('support_inquiry_messages').insert({
        'inquiry_id': inquiryId,
        'sender_role': senderRole,
        'sender_email': senderEmail,
        'message': message,
        'attachments': (attachments ?? const [])
            .map((a) => a.toJson())
            .toList(growable: false),
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 메시지 realtime 구독
  RealtimeChannel? subscribeToInquiryMessages({
    required int inquiryId,
    required Function(PostgresChangePayload payload) onChange,
  }) {
    try {
      return _supabase
          .channel('support_inquiry_messages_$inquiryId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'support_inquiry_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'inquiry_id',
              value: inquiryId,
            ),
            callback: onChange,
          )
          .subscribe();
    } catch (e) {
      return null;
    }
  }

  /// 완료 처리 (관리자만) - RPC: resolve_inquiry
  Future<Map<String, dynamic>> resolveInquiry(int inquiryId) async {
    try {
      final res = await _supabase.rpc('resolve_inquiry', params: {
        'p_inquiry_id': inquiryId,
      });
      // rpc 성공 시 res는 void일 수 있음
      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// (웹과 동일) 해당 문의의 알림(inquiry_message/inquiry_resolved)을 읽음 처리
  Future<void> markInquiryNotificationsAsRead(int inquiryId) async {
    try {
      final user = _supabase.auth.currentUser;
      final email = user?.email;
      if (email == null || email.isEmpty) return;

      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_email', email)
          .eq('is_read', false)
          .inFilter('type', ['inquiry_message', 'inquiry_resolved'])
          .eq('data->>inquiryId', inquiryId.toString());
    } catch (e) {
      // 읽음 처리 실패는 UX를 막지 않음
    }
  }

  /// 문의 목록 조회 (일반: 내 문의만, 관리자: 모든 문의)
  Future<List<Map<String, dynamic>>> getInquiries() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final isAdmin = await isAppAdmin();

      // Debug code removed

      // 관리자는 모든 문의 조회
      if (isAdmin) {
        final response = await _supabase
            .from('support_inquires')
            .select('*')
            .order('created_at', ascending: false);

        // Debug code removed

        return List<Map<String, dynamic>>.from(response);
      }
      else {
        final response = await _supabase
            .from('support_inquires')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        // Debug code removed

        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      // Debug code removed
      return [];
    }
  }

  /// 문의 상태 업데이트 (관리자만 가능)
  Future<Map<String, dynamic>> updateInquiryStatus({
    required int inquiryId,
    required String status,
    String? resolutionNote,
  }) async {
    try {
      // 관리자 권한 확인
      if (!await isAppAdmin()) {
        return {
          'success': false,
          'error': '권한이 없습니다.',
          'message': '관리자만 상태를 변경할 수 있습니다.',
        };
      }

      // Debug code removed

      final user = _supabase.auth.currentUser;
      final userEmail = user?.email ?? '';

      // 관리자 이름 가져오기
      String handledBy = userEmail;
      try {
        final employeeData = await _supabase
            .from('employees')
            .select('name')
            .eq('email', userEmail)
            .single();
        handledBy = employeeData['name'] ?? userEmail;
      } catch (e) {
        // 이름을 못 가져오면 이메일 사용
      }

      final updateData = <String, dynamic>{
        'status': status,
        'handled_by': handledBy,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 해결됨 상태일 때 처리 시간 기록
      if (status == 'resolved' || status == 'closed') {
        updateData['processed_at'] = DateTime.now().toIso8601String();
      }

      if (resolutionNote != null && resolutionNote.isNotEmpty) {
        updateData['resolution_note'] = resolutionNote;
      }

      final response = await _supabase
          .from('support_inquires')
          .update(updateData)
          .eq('id', inquiryId)
          .select()
          .single();

      // Debug code removed

      return {'success': true, 'data': response, 'message': '상태가 업데이트되었습니다.'};
    } catch (e) {
      // Debug code removed
      return {
        'success': false,
        'error': e.toString(),
        'message': '상태 업데이트에 실패했습니다.',
      };
    }
  }

  /// 문의 상세 조회
  Future<Map<String, dynamic>?> getInquiryDetail(int inquiryId) async {
    try {
      final response = await _supabase
          .from('support_inquires')
          .select('*')
          .eq('id', inquiryId)
          .single();

      return response;
    } catch (e) {
      // Debug code removed
      return null;
    }
  }

  /// 실시간 문의 업데이트 구독 (답변 알림용)
  RealtimeChannel? subscribeToInquiryUpdates({
    required Function(Map<String, dynamic>) onUpdate,
  }) {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug code removed
        return null;
      }

      // Debug code removed

      // 일반 사용자는 본인 문의만, 관리자는 모든 문의 구독
      return _supabase
          .channel('inquiry_updates_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_inquires',
            callback: (payload) async {
              final newRecord = payload.newRecord;

              final isAdmin = await isAppAdmin();
              if (!isAdmin && newRecord['user_id'] != user.id) {
                return;
              }

              onUpdate(newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'support_inquires',  // 올바른 테이블명
            callback: (payload) async {
              final newRecord = payload.newRecord;

              // 관리자인지 확인
              final isAdmin = await isAppAdmin();

              // 관리자가 아니면 본인 문의만 필터링
              if (!isAdmin && newRecord['user_id'] != user.id) {
                return;
              }

              // Debug code removed

              onUpdate(newRecord);
            },
          )
          .subscribe();
    } catch (e) {
      // Debug code removed
      return null;
    }
  }

  /// 실시간 알림 구독 (문의 메시지/완료 알림 기반 뱃지 갱신용)
  /// - notifications.user_email == 현재 사용자
  /// - type in (inquiry_message, inquiry_resolved, inquiry_response)
  RealtimeChannel? subscribeToInquiryNotificationUpdates({
    required Function() onUpdate,
  }) {
    try {
      final user = _supabase.auth.currentUser;
      final email = user?.email;
      if (email == null || email.isEmpty) return null;

      return _supabase
          .channel('inquiry_notifications_$email')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_email',
              value: email,
            ),
            callback: (payload) {
              final type = (payload.newRecord['type'] ?? '').toString();
              if (type == 'inquiry_message' ||
                  type == 'inquiry_resolved' ||
                  type == 'inquiry_response') {
                onUpdate();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_email',
              value: email,
            ),
            callback: (payload) {
              final type = (payload.newRecord['type'] ?? '').toString();
              if (type == 'inquiry_message' ||
                  type == 'inquiry_resolved' ||
                  type == 'inquiry_response') {
                onUpdate();
              }
            },
          )
          .subscribe();
    } catch (e) {
      return null;
    }
  }

  /// 구독 해제
  void unsubscribe(RealtimeChannel? channel) {
    if (channel != null) {
      _supabase.removeChannel(channel);
      // Debug code removed
    }
  }

  /// Flutter 앱용 문의 유형 목록
  static List<Map<String, String>> getInquiryTypes() {
    return [
      {'value': 'delivery_date_change', 'label': '입고일 변경 요청'},
      {'value': 'quantity_change', 'label': '수량 변경 요청'},
      {'value': 'price_change', 'label': '단가/합계 금액 변경 요청'},
      {'value': 'item_add', 'label': '품목 추가 요청'},
      {'value': 'bug', 'label': '오류 신고'},
      {'value': 'modify', 'label': '수정 요청'},
      {'value': 'delete', 'label': '삭제 요청'},
      {'value': 'other', 'label': '기타 문의'},
    ];
  }

  /// 문의 상태 라벨 가져오기
  static String getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return '대기중';
      case 'in_progress':
        return '처리중';
      case 'resolved':
        return '해결됨';
      case 'closed':
        return '종료';
      default:
        return status;
    }
  }

  /// 문의 상태 색상 가져오기
  static int getStatusColor(String status) {
    switch (status) {
      case 'open':
        return 0xFFFFA726; // 주황색 - 대기중
      case 'in_progress':
        return 0xFF2196F3; // 파란색 - 처리중
      case 'resolved':
        return 0xFF4CAF50; // 초록색 - 해결됨
      case 'closed':
        return 0xFF9E9E9E; // 회색 - 종료
      default:
        return 0xFF9E9E9E;
    }
  }

  /// 문의 유형 라벨 가져오기 (DB 값을 한글로 변환)
  static String getInquiryTypeLabel(String? type) {
    if (type == null) return '기타';

    switch (type) {
      case 'bug':
        return '오류 신고';
      case 'delivery_date_change':
        return '입고일 변경 요청';
      case 'quantity_change':
        return '수량 변경 요청';
      case 'price_change':
        return '단가/합계 금액 변경 요청';
      case 'item_add':
        return '품목 추가 요청';
      case 'modify':
        return '수정 요청';
      case 'delete':
        return '삭제 요청';
      case 'annual_leave':
      case 'attendance':
        return '기타 문의';
      case 'other':
        return '기타';
      case '오류':
        return '오류 신고';
      default:
        return type;
    }
  }

  /// 발주요청 목록 조회 (문의 작성용)
  Future<Map<String, dynamic>> getMyPurchaseRequests({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) {
        return {'success': false, 'data': [], 'error': '로그인이 필요합니다.'};
      }

      final employee = await _supabase
          .from('employees')
          .select('name')
          .eq('email', user.email!)
          .single();

      final requesterName = (employee['name'] ?? '').toString();
      if (requesterName.isEmpty) {
        return {
          'success': false,
          'data': [],
          'error': '사용자 정보를 찾을 수 없습니다.',
        };
      }

      var query = _supabase
          .from('purchase_requests')
          .select(
            'id,purchase_order_number,vendor_name,request_date,created_at,requester_name,'
            'middle_manager_status,final_manager_status,delivery_request_date,'
            'revised_delivery_request_date,purchase_request_items('
            'id,line_number,item_name,specification,quantity,unit_price_value,amount_value'
            ')',
          )
          .eq('requester_name', requesterName);

      if (startDate != null) {
        query = query.gte(
          'created_at',
          DateTime(startDate.year, startDate.month, startDate.day)
              .toUtc()
              .toIso8601String(),
        );
      }
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('created_at', end.toUtc().toIso8601String());
      }

      final data = await query
          .order('created_at', ascending: false)
          .limit(100);
      return {'success': true, 'data': List<Map<String, dynamic>>.from(data)};
    } catch (e) {
      return {
        'success': false,
        'data': [],
        'error': e.toString(),
      };
    }
  }

  /// 발주요청 상세 조회
  Future<Map<String, dynamic>?> getPurchaseRequestDetail(int requestId) async {
    try {
      final response = await _supabase
          .from('purchase_requests')
          .select(
            'id,purchase_order_number,vendor_name,requester_name,request_date,'
            'created_at,delivery_request_date,revised_delivery_request_date,'
            'purchase_request_items('
            'id,line_number,item_name,specification,quantity,unit_price_value,amount_value,remark,link'
            ')',
          )
          .eq('id', requestId)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      return null;
    }
  }

  /// 발주요청 ID 조회 (발주번호 → ID)
  Future<int?> getPurchaseRequestIdByOrderNumber(String orderNumber) async {
    try {
      final response = await _supabase
          .from('purchase_requests')
          .select('id')
          .eq('purchase_order_number', orderNumber)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return (response['id'] as num?)?.toInt();
    } catch (e) {
      return null;
    }
  }

  /// 발주요청 품목 수정
  Future<Map<String, dynamic>> updatePurchaseRequestItem({
    required int itemId,
    String? itemName,
    String? specification,
    int? quantity,
    int? unitPriceValue,
    int? amountValue,
    String? remark,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (itemName != null) updateData['item_name'] = itemName;
      if (specification != null) updateData['specification'] = specification;
      if (quantity != null) updateData['quantity'] = quantity;
      if (unitPriceValue != null) {
        updateData['unit_price_value'] = unitPriceValue;
        updateData['unit_price_currency'] = 'KRW';
      }
      if (amountValue != null) {
        updateData['amount_value'] = amountValue;
        updateData['amount_currency'] = 'KRW';
      }
      if (remark != null) updateData['remark'] = remark;

      await _supabase
          .from('purchase_request_items')
          .update(updateData)
          .eq('id', itemId);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 발주요청 품목 삭제
  Future<Map<String, dynamic>> deletePurchaseRequestItem(int itemId) async {
    try {
      await _supabase
          .from('purchase_request_items')
          .delete()
          .eq('id', itemId);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 발주요청 전체 삭제 (문의 기록 보존 포함)
  Future<Map<String, dynamic>> deletePurchaseRequestWithInquiryPreserved(
    int requestId,
  ) async {
    try {
      await _supabase
          .from('support_inquires')
          .update({'purchase_request_id': null})
          .eq('purchase_request_id', requestId);

      await _supabase
          .from('purchase_request_items')
          .delete()
          .eq('purchase_request_id', requestId);

      await _supabase
          .from('purchase_requests')
          .delete()
          .eq('id', requestId);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 입고일 수정요청 완료 플래그 업데이트
  Future<Map<String, dynamic>> markDeliveryRevisionRequested({
    required int requestId,
    required String requesterName,
  }) async {
    try {
      await _supabase
          .from('purchase_requests')
          .update({
            'delivery_revision_requested': true,
            'delivery_revision_requested_at':
                DateTime.now().toUtc().toIso8601String(),
            'delivery_revision_requested_by': requesterName,
          })
          .eq('id', requestId);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 플랫폼 라벨 가져오기
  static String getPlatformLabel(Map<String, dynamic> inquiry) {
    // purchase_request_id가 있으면 웹에서 작성한 발주 관련 문의
    if (inquiry['purchase_request_id'] != null) {
      return '웹(발주)';
    }
    // 그 외는 플랫폼 정보가 없으므로 생성 시간으로 추정
    // 또는 subject나 message에 특정 키워드가 있는지 확인
    return '앱';
  }

  /// 미처리 문의 개수 조회 (관리자용)
  Future<int> getUnprocessedCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      // 관리자가 아니면 0 반환
      if (!await isAppAdmin()) return 0;

      final response = await _supabase
          .from('support_inquires')
          .select('*')
          .or('status.eq.open,status.eq.in_progress');

      return (response as List).length;
    } catch (e) {
      // Debug code removed
      return 0;
    }
  }

  /// 미확인 답변 개수 조회 (일반 사용자용)
  Future<int> getUnreadResponseCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      // 관리자면 0 반환
      if (await isAppAdmin()) return 0;

      // 웹/신규 문의 시스템 기준:
      // notifications에 type = inquiry_message / inquiry_resolved 가 저장되며,
      // 문의 상세 열람 시 해당 inquiryId 알림을 읽음 처리한다.
      final response = await _supabase
          .from('notifications')
          .select('id,type')
          .eq('user_email', user.email!)
          .eq('is_read', false)
          .inFilter('type', ['inquiry_message', 'inquiry_resolved', 'inquiry_response']);

      return (response as List).length;
    } catch (e) {
      // Debug code removed
      return 0;
    }
  }

  /// 문의 답변 확인 처리
  Future<void> markInquiryAsRead(int inquiryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readList = prefs.getStringList('read_inquiries') ?? [];

      if (!readList.contains(inquiryId.toString())) {
        readList.add(inquiryId.toString());
        await prefs.setStringList('read_inquiries', readList);
      }
    } catch (e) {
      // Debug code removed
    }
  }

  /// 읽은 문의 목록 가져오기
  Future<Set<int>> _getReadInquiries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readList = prefs.getStringList('read_inquiries') ?? [];
      return readList.map((id) => int.tryParse(id) ?? 0).toSet();
    } catch (e) {
      return {};
    }
  }

  /// 문의 삭제 (본인 문의는 언제든 삭제 가능)
  Future<Map<String, dynamic>> deleteInquiry(int inquiryId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': '인증이 필요합니다.',
          'message': '로그인 후 다시 시도해주세요.',
        };
      }

      // Debug code removed

      // 문의 정보 확인
      final inquiry = await _supabase
          .from('support_inquires')
          .select('*')
          .eq('id', inquiryId)
          .single();

      final isAdmin = await isAppAdmin();

      // 권한 확인: 본인이 작성한 문의이거나 관리자인 경우만 삭제 가능
      if (!isAdmin && inquiry['user_id'] != user.id) {
        return {
          'success': false,
          'error': '권한이 없습니다.',
          'message': '본인이 작성한 문의만 삭제할 수 있습니다.',
        };
      }

      // 일반 사용자는 처리된 문의 삭제 불가 (RLS 정책과 동일)
      if (!isAdmin) {
        final status = (inquiry['status'] ?? 'open').toString();
        final resolutionNote = (inquiry['resolution_note'] ?? '').toString();
        if (status != 'open') {
          return {
            'success': false,
            'error': '처리된 문의는 삭제할 수 없습니다.',
            'message': '처리가 진행된 문의는 삭제할 수 없습니다.',
          };
        }
        if (resolutionNote.isNotEmpty) {
          return {
            'success': false,
            'error': '답변이 완료된 문의는 삭제할 수 없습니다.',
            'message': '답변이 완료된 문의는 삭제할 수 없습니다.',
          };
        }
      }

      await _supabase
          .from('support_inquires')
          .delete()
          .eq('id', inquiryId);

      // Debug code removed

      // 읽음 처리 목록에서도 제거
      try {
        final prefs = await SharedPreferences.getInstance();
        final readList = prefs.getStringList('read_inquiries') ?? [];
        readList.remove(inquiryId.toString());
        await prefs.setStringList('read_inquiries', readList);
      } catch (e) {
        // 읽음 처리 목록 제거 실패는 무시
      }

      return {
        'success': true,
        'message': '문의가 성공적으로 삭제되었습니다.',
      };
    } catch (e) {
      // Debug code removed
      return {
        'success': false,
        'error': e.toString(),
        'message': '문의 삭제에 실패했습니다.\n잠시 후 다시 시도해주세요.',
      };
    }
  }

  /// 문의 삭제 가능 여부 확인
  Future<Map<String, dynamic>> canDeleteInquiry(int inquiryId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'canDelete': false,
          'reason': '로그인이 필요합니다.',
        };
      }

      final inquiry = await _supabase
          .from('support_inquires')
          .select('*')
          .eq('id', inquiryId)
          .single();

      final isAdmin = await isAppAdmin();

      // 권한 확인 - 관리자는 모든 문의 삭제 가능
      if (isAdmin) {
        return {
          'canDelete': true,
          'reason': '관리자 권한으로 삭제 가능',
        };
      }

      // 일반 사용자는 본인이 작성한 문의만 삭제 가능
      if (inquiry['user_id'] != user.id) {
        return {
          'canDelete': false,
          'reason': '본인이 작성한 문의만 삭제할 수 있습니다.',
        };
      }

      final status = (inquiry['status'] ?? 'open').toString();
      final resolutionNote = (inquiry['resolution_note'] ?? '').toString();
      if (status != 'open') {
        return {
          'canDelete': false,
          'reason': '처리가 진행된 문의는 삭제할 수 없습니다.',
        };
      }
      if (resolutionNote.isNotEmpty) {
        return {
          'canDelete': false,
          'reason': '답변이 완료된 문의는 삭제할 수 없습니다.',
        };
      }

      return {
        'canDelete': true,
        'reason': '삭제 가능',
      };
    } catch (e) {
      return {
        'canDelete': false,
        'reason': '확인 중 오류가 발생했습니다.',
      };
    }
  }
}
