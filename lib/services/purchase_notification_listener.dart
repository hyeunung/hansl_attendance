import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseNotificationListener {
  
  static final _supabase = Supabase.instance.client;
  static RealtimeChannel? _channel;
  
  /// 발주 알림 실시간 리스너 시작
  static void startListening() {
    // 백엔드(DB 트리거)에서만 FCM 푸시 알림을 보내므로
    // 프론트엔드 리스너는 사용하지 않음 (중복 방지)
    // notifications 테이블 변경시 백엔드 트리거가 자동으로 FCM 전송
    return;
  }
  
  /// 실시간 리스너 중지
  static void stopListening() {
    _channel?.unsubscribe();
    _channel = null;
    
    // Debug code removed
  }
  
  // _sendLocalFCMNotification 함수 제거
  // 모든 FCM 알림은 백엔드 트리거에서 처리
}
