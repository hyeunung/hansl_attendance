import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SlackService {
  /// 슬랙으로 문의 메시지를 전송합니다 (근태앱 전용)
  Future<bool> sendInquiryToSlack({
    required String inquiryContent,
    required String userEmail,
    required String userName,
  }) async {
    try {
      if (kDebugMode) {
        if (kDebugMode) print('📤 근태앱 문의 메시지 슬랙 전송 시작...');
      }

      // Supabase 프로젝트 URL에서 Edge Function 호출
      final projectId = 'qvhbigvdfyvhoegkhvef'; // 프로젝트 ID
      final functionUrl =
          'https://$projectId.supabase.co/functions/v1/send_slack_notification_attendance';

      // 사용자 정보 가져오기
      final session = Supabase.instance.client.auth.currentSession;
      final accessToken = session?.accessToken;

      if (accessToken == null) {
        if (kDebugMode) {
          if (kDebugMode) print('❌ 인증 토큰이 없습니다.');
        }
        return false;
      }

      // 사용자 부서 정보 가져오기
      String? userDepartment;
      try {
        final userResponse = await Supabase.instance.client
            .from('employees')
            .select('department')
            .eq('email', userEmail)
            .single();
        userDepartment = userResponse['department'] as String?;
      } catch (e) {
        if (kDebugMode) {
          if (kDebugMode) print('⚠️ 사용자 부서 정보 조회 실패: $e');
        }
      }

      final requestData = {
        'type': 'inquiry',
        'title': '🆘 문의사항',
        'message': inquiryContent,
        'inquiry_content': inquiryContent,
        'user_email': userEmail,
        'user_name': userName,
        'requester_department': userDepartment,
        'requester_email': userEmail,
      };

      if (kDebugMode) {
        if (kDebugMode) {
          print('📮 Edge Function 호출: send_slack_notification_attendance');
        }
      }

      final response = await http
          .post(
            Uri.parse(functionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(requestData),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Edge Function 호출 타임아웃 (30초)');
            },
          );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (kDebugMode) {
            if (kDebugMode) {
              print('✅ 근태앱 문의 메시지 슬랙 전송 성공: ${responseData['message']}');
            }
          }
          return true;
        } else {
          if (kDebugMode) {
            if (kDebugMode) {
              print('❌ 근태앱 문의 메시지 슬랙 전송 실패: ${responseData['message']}');
            }
          }
          return false;
        }
      } else {
        if (kDebugMode) {
          if (kDebugMode) {
            print(
              '❌ Edge Function 호출 실패: ${response.statusCode} - ${response.body}',
            );
          }
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('❌ 슬랙 문의 메시지 전송 중 오류: $e');
        if (e.toString().contains('타임아웃')) {
          if (kDebugMode) print('   네트워크 연결이 느리거나 서버에 문제가 있을 수 있습니다.');
        } else if (e.toString().contains('SocketException')) {
          if (kDebugMode) print('   인터넷 연결을 확인해주세요.');
        }
      }
      return false;
    }
  }
}
