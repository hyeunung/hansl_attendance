import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 문의하기 서비스
/// - 일반 직원: 문의 작성 및 본인 문의 조회
/// - app_admin: 모든 문의 조회 및 답변/상태 변경
class InquiryService {
  final _supabase = Supabase.instance.client;

  /// 사용자 권한 확인 (app_admin 여부)
  Future<bool> isAppAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) return false;

      final response = await _supabase
          .from('employees')
          .select('purchase_role')
          .eq('email', user.email!)
          .maybeSingle();

      if (response == null) return false;
      final purchaseRole = response['purchase_role'];

      // purchase_role이 문자열 배열 또는 쉼표로 구분된 문자열일 수 있음
      if (purchaseRole is List) {
        return purchaseRole.contains('app_admin');
      } else if (purchaseRole is String) {
        return purchaseRole
            .split(',')
            .map((e) => e.trim())
            .contains('app_admin');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 권한 확인 실패: $e');
      }
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
  }) async {
    try {
      // app_admin은 문의 생성 불가
      if (await isAppAdmin()) {
        return {
          'success': false,
          'error': '관리자는 문의를 작성할 수 없습니다.',
          'message': '관리자는 문의 내역 확인 및 답변만 가능합니다.',
        };
      }

      if (kDebugMode) {
        print('📝 문의 생성 시작...');
        print('- 유형: $inquiryType');
        print('- 제목: $subject');
        print('- 작성자: $userName ($userEmail)');
      }

      final user = _supabase.auth.currentUser;

      // Flutter 앱 문의 유형을 DB 유형으로 매핑
      String dbInquiryType = inquiryType;
      if (inquiryType == '앱관련') {
        dbInquiryType = 'other'; // 앱관련은 other로 저장
      } else if (inquiryType == '오류') {
        dbInquiryType = 'bug';
      } else if (inquiryType == '기타') {
        dbInquiryType = 'other';
      }

      final data = {
        'user_id': user?.id,
        'user_email': userEmail,
        'user_name': userName,
        'inquiry_type': dbInquiryType,
        'subject': subject,
        'message': message,
        'status': 'open',
      };

      final response = await _supabase
          .from('support_inquiries')
          .insert(data)
          .select()
          .single();

      if (kDebugMode) {
        print('✅ 문의 생성 성공: #${response['id']}');
      }

      return {
        'success': true,
        'data': response,
        'message': '문의가 성공적으로 등록되었습니다.\n관리자가 확인 후 답변드리겠습니다.',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 문의 생성 실패: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'message': '문의 등록에 실패했습니다.\n잠시 후 다시 시도해주세요.',
      };
    }
  }

  /// 문의 목록 조회 (일반: 내 문의만, 관리자: 모든 문의)
  Future<List<Map<String, dynamic>>> getInquiries() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final isAdmin = await isAppAdmin();

      if (kDebugMode) {
        print('📋 문의 목록 조회 (관리자: $isAdmin)');
      }

      // 관리자는 모든 문의 조회
      if (isAdmin) {
        final response = await _supabase
            .from('support_inquiries')
            .select('*')
            .order('created_at', ascending: false);

        if (kDebugMode) {
          print('✅ 전체 문의 ${response.length}건 조회 완료');
        }

        return List<Map<String, dynamic>>.from(response);
      }
      // 일반 직원은 본인 문의만 조회 (Flutter + 웹에서 작성한 것 모두)
      else {
        final response = await _supabase
            .from('support_inquiries')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        if (kDebugMode) {
          print('✅ 내 문의 ${response.length}건 조회 완료');
        }

        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 문의 목록 조회 실패: $e');
      }
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

      if (kDebugMode) {
        print('📝 문의 #$inquiryId 상태 업데이트: $status');
      }

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
          .from('support_inquiries')
          .update(updateData)
          .eq('id', inquiryId)
          .select()
          .single();

      if (kDebugMode) {
        print('✅ 문의 상태 업데이트 성공');
      }

      return {'success': true, 'data': response, 'message': '상태가 업데이트되었습니다.'};
    } catch (e) {
      if (kDebugMode) {
        print('❌ 문의 상태 업데이트 실패: $e');
      }
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
          .from('support_inquiries')
          .select('*')
          .eq('id', inquiryId)
          .single();

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 문의 상세 조회 실패: $e');
      }
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
        if (kDebugMode) {
          print('❌ 실시간 구독 실패: 사용자 인증 필요');
        }
        return null;
      }

      if (kDebugMode) {
        print('🔔 실시간 문의 업데이트 구독 시작');
      }

      // 일반 사용자는 본인 문의만, 관리자는 모든 문의 구독
      return _supabase
          .channel('inquiry_updates_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'support_inquiries',
            callback: (payload) async {
              final newRecord = payload.newRecord;

              // 관리자인지 확인
              final isAdmin = await isAppAdmin();

              // 관리자가 아니면 본인 문의만 필터링
              if (!isAdmin && newRecord['user_id'] != user.id) {
                return;
              }

              if (kDebugMode) {
                print('🔔 문의 업데이트 수신: #${newRecord['id']}');
              }

              onUpdate(newRecord);
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 실시간 구독 설정 실패: $e');
      }
      return null;
    }
  }

  /// 구독 해제
  void unsubscribe(RealtimeChannel? channel) {
    if (channel != null) {
      _supabase.removeChannel(channel);
      if (kDebugMode) {
        print('🔕 실시간 구독 해제');
      }
    }
  }

  /// Flutter 앱용 문의 유형 목록
  static List<Map<String, String>> getInquiryTypes() {
    return [
      {'value': '연차', 'label': '연차'},
      {'value': '근태', 'label': '근태'},
      {'value': '오류', 'label': '오류'},
      {'value': '기타', 'label': '기타'},
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
        return '오류';
      case 'modify':
        return '수정 요청';
      case 'delete':
        return '삭제 요청';
      case 'other':
        return '기타';
      default:
        return type;
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
          .from('support_inquiries')
          .select('*')
          .or('status.eq.open,status.eq.in_progress');

      return (response as List).length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 미처리 문의 개수 조회 실패: $e');
      }
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

      // 본인의 resolved 또는 closed 상태 문의 중
      // resolution_note가 있고 아직 확인하지 않은 것
      // (확인 여부는 별도 필드가 없으므로 resolved/closed 상태인 것으로 판단)
      final response = await _supabase
          .from('support_inquiries')
          .select('*')
          .eq('user_id', user.id)
          .or('status.eq.resolved,status.eq.closed')
          .not('resolution_note', 'is', null);

      // 로컬 스토리지에서 읽은 문의 ID 목록 가져오기
      // (SharedPreferences 필요)
      final readInquiries = await _getReadInquiries();

      final unreadCount = (response as List)
          .where((inquiry) => !readInquiries.contains(inquiry['id']))
          .length;

      return unreadCount;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 미확인 답변 개수 조회 실패: $e');
      }
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
      if (kDebugMode) {
        print('❌ 문의 읽음 처리 실패: $e');
      }
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

      if (kDebugMode) {
        print('🗑️ 문의 #$inquiryId 삭제 요청');
      }

      // 문의 정보 확인
      final inquiry = await _supabase
          .from('support_inquiries')
          .select('*')
          .eq('id', inquiryId)
          .single();

      if (inquiry == null) {
        return {
          'success': false,
          'error': '문의를 찾을 수 없습니다.',
          'message': '문의가 존재하지 않거나 이미 삭제되었습니다.',
        };
      }

      final isAdmin = await isAppAdmin();

      // 권한 확인: 본인이 작성한 문의이거나 관리자인 경우만 삭제 가능
      if (!isAdmin && inquiry['user_id'] != user.id) {
        return {
          'success': false,
          'error': '권한이 없습니다.',
          'message': '본인이 작성한 문의만 삭제할 수 있습니다.',
        };
      }

      // 삭제 실행 (답변 유무와 관계없이 삭제 가능)
      await _supabase
          .from('support_inquiries')
          .delete()
          .eq('id', inquiryId);

      if (kDebugMode) {
        print('✅ 문의 #$inquiryId 삭제 완료');
      }

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
      if (kDebugMode) {
        print('❌ 문의 삭제 실패: $e');
      }
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
          .from('support_inquiries')
          .select('*')
          .eq('id', inquiryId)
          .single();

      if (inquiry == null) {
        return {
          'canDelete': false,
          'reason': '문의를 찾을 수 없습니다.',
        };
      }

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
