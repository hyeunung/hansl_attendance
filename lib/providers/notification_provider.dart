import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? error;
  
  // Debug logging function removed

  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;

  // 초기화
  Future<void> initialize() async {
    await loadNotifications();
    _setupRealtimeSubscription();
  }

  // 알림 목록 로드
  Future<void> loadNotifications() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_email', user.email!)
          .order('created_at', ascending: false);

      _notifications = List<Map<String, dynamic>>.from(response);
      _updateUnreadCount();
    } catch (e) {
      error = '알림을 불러오는 중 오류가 발생했습니다';
      _notifications = [];
      _unreadCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 읽지 않은 알림 개수 업데이트
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => n['is_read'] == false).length;
  }

  // 알림을 읽음으로 표시
  Future<void> markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      // 로컬 상태 업데이트
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      error = '알림 읽음 처리 중 오류가 발생했습니다';
      notifyListeners();
    }
  }

  // 모든 알림을 읽음으로 표시
  Future<void> markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_email', user.email!)
          .eq('is_read', false);

      // 로컬 상태 업데이트
      for (var notification in _notifications) {
        if (notification['is_read'] == false) {
          notification['is_read'] = true;
          notification['read_at'] = DateTime.now().toIso8601String();
        }
      }

      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      error = '모든 알림 읽음 처리 중 오류가 발생했습니다';
      notifyListeners();
    }
  }

  // 알림 삭제
  Future<void> deleteNotification(int notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);

      _notifications.removeWhere((n) => n['id'] == notificationId);
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      error = '알림 삭제 중 오류가 발생했습니다';
      notifyListeners();
    }
  }

  // 실시간 알림 구독
  void _setupRealtimeSubscription() {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _supabase
          .channel('notifications_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_email',
              value: user.email,
            ),
            callback: (payload) {
              // 새 알림을 목록 맨 앞에 추가
              _notifications.insert(0, payload.newRecord);
              _updateUnreadCount();
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      // 테이블이 없는 경우 무시
      if (kDebugMode && !e.toString().contains('42P01')) {
        // Debug print removed
}
    }
  }

  // 정리
  @override
  void dispose() {
    _supabase.removeChannel(_supabase.channel('notifications_channel'));
    super.dispose();
  }

  // 로그아웃 시 초기화
  void clear() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }
}
