# HANSL Flutter App - API Integration Guide

## Overview
This guide covers all external API integrations in the HANSL Flutter app, including Supabase backend services, Firebase notifications, and Slack messaging.

## Supabase Integration

### Configuration
```dart
// Direct initialization (simplified approach)
await Supabase.initialize(
  url: 'https://qvhbigvdfyvhoegkhvef.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg',
);
```

### Authentication API

#### Login Flow
```dart
Future<void> authenticateUser(String email, String password) async {
  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user != null) {
      // Fetch employee data
      final employee = await Supabase.instance.client
          .from('employees')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (employee != null) {
        // Set user in provider
        final userProvider = context.read<UserProvider>();
        userProvider.setUser(
          id: employee['id'],
          name: employee['name'],
          email: employee['email'],
        );
        userProvider.setEmployee(employee);
      }
    }
  } catch (e) {
    throw Exception('로그인 실패: $e');
  }
}
```

#### Auto-Login Verification
```dart
Future<bool> checkAutoLogin() async {
  try {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null && session.user != null) {
      final email = session.user!.email;
      
      if (email != null) {
        final employee = await Supabase.instance.client
            .from('employees')
            .select()
            .eq('email', email)
            .maybeSingle();
            
        if (employee != null) {
          // Setup user provider
          final userProvider = context.read<UserProvider>();
          userProvider.setUser(
            id: employee['id'],
            name: employee['name'],
            email: employee['email'],
          );
          userProvider.setEmployee(employee);
          return true;
        }
      }
    }
    return false;
  } catch (e) {
    print('Auto-login error: $e');
    return false;
  }
}
```

### Database Operations

#### Employee Management
```dart
// Fetch employee data
Future<Map<String, dynamic>?> getEmployee(String email) async {
  return await Supabase.instance.client
      .from('employees')
      .select('''
        id, name, email, department, role, 
        attendance_role, slack_id, join_date
      ''')
      .eq('email', email)
      .maybeSingle();
}

// Update employee information
Future<void> updateEmployee(String id, Map<String, dynamic> updates) async {
  await Supabase.instance.client
      .from('employees')
      .update(updates)
      .eq('id', id);
}
```

#### Attendance Tracking
```dart
// Clock in
Future<void> clockIn(String userId, double lat, double lng) async {
  await Supabase.instance.client
      .from('attendance')
      .insert({
        'user_id': userId,
        'clock_in': DateTime.now().toIso8601String(),
        'latitude': lat,
        'longitude': lng,
        'status': 'present',
      });
}

// Clock out
Future<void> clockOut(String userId) async {
  await Supabase.instance.client
      .from('attendance')
      .update({
        'clock_out': DateTime.now().toIso8601String(),
      })
      .eq('user_id', userId)
      .eq('date', DateTime.now().toIso8601String().split('T')[0]);
}
```

#### Leave Management
```dart
// Submit leave request
Future<void> submitLeaveRequest(Map<String, dynamic> leaveData) async {
  await Supabase.instance.client
      .from('leave_requests')
      .insert({
        'user_id': leaveData['userId'],
        'type': leaveData['type'],
        'start_date': leaveData['startDate'],
        'end_date': leaveData['endDate'],
        'reason': leaveData['reason'],
        'destination': leaveData['destination'], // for business trips
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
}

// Fetch leave requests for approval
Future<List<Map<String, dynamic>>> getLeaveRequestsForApproval() async {
  return await Supabase.instance.client
      .from('leave_requests')
      .select('''
        *, employees:employees!leave_requests_user_id_fkey (
          id, name, email, department
        )
      ''')
      .order('created_at', ascending: false);
}

// Update leave request status
Future<void> updateLeaveStatus(String requestId, String status) async {
  await Supabase.instance.client
      .from('leave_requests')
      .update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', requestId);
}
```

### Edge Functions Integration

#### Annual Leave Calculation
```dart
// Trigger annual leave calculation
Future<void> calculateAnnualLeave(String userId) async {
  await Supabase.instance.client.functions.invoke(
    'calculate_annual_leave',
    body: {'user_id': userId},
  );
}
```

#### Slack Notifications
```dart
// Send approval notification
Future<void> sendApprovalNotification(String requestId, String status) async {
  await Supabase.instance.client.functions.invoke(
    'send_slack_notification_attendance',
    body: {
      'request_id': requestId,
      'status': status,
      'notification_type': 'approval',
    },
  );
}
```

### Real-time Subscriptions
```dart
class LeaveProvider extends ChangeNotifier {
  late final RealtimeChannel _channel;
  
  void setupRealtimeListener() {
    _channel = Supabase.instance.client
        .channel('leave_requests')
        .on(RealtimeListenTypes.postgresChanges, 
            ChannelFilter(
              event: '*',
              schema: 'public',
              table: 'leave_requests',
            ), (payload, [ref]) {
          // Handle real-time updates
          fetchAllLeaves();
        }).subscribe();
  }
  
  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }
}
```

## Firebase Integration

### Configuration
```dart
// Initialize Firebase
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

// Setup messaging
await NotificationService.initialize();
```

### Push Notifications

#### Service Setup
```dart
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Push notification permission granted');
      
      // Get FCM token
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Store token in Supabase for server-side notifications
        await _storeFCMToken(token);
      }
    }
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }
  
  static Future<void> _storeFCMToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('employees')
          .update({'fcm_token': token})
          .eq('email', user.email);
    }
  }
}
```

#### Message Handling
```dart
// Foreground message handler
static void _handleForegroundMessage(RemoteMessage message) {
  print('Received foreground message: ${message.messageId}');
  
  // Show local notification
  _showLocalNotification(
    title: message.notification?.title ?? 'HANSL',
    body: message.notification?.body ?? '',
    data: message.data,
  );
}

// Background message handler
@pragma('vm:entry-point')
static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
  // Handle background processing
}

// Notification tap handler
static void _handleNotificationTap(RemoteMessage message) {
  print('Notification tapped: ${message.data}');
  
  // Navigate based on notification type
  final notificationType = message.data['type'];
  if (notificationType == 'leave_approval') {
    navigatorKey.currentState?.pushNamed('/approval');
  }
}
```

## Slack Integration

### Webhook Configuration
```typescript
// Supabase Edge Function: send_slack_notification_attendance
const slackWebhookUrl = 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL';

export async function sendSlackNotification(
  requestData: {
    userId: string;
    type: string;
    status: string;
    message: string;
  }
) {
  try {
    // Get employee Slack ID
    const { data: employee } = await supabase
      .from('employees')
      .select('slack_id, name')
      .eq('id', requestData.userId)
      .single();
    
    if (!employee?.slack_id) {
      throw new Error('No Slack ID found for user');
    }
    
    // Send direct message
    const slackPayload = {
      channel: employee.slack_id,
      text: requestData.message,
      attachments: [{
        color: requestData.status === 'approved' ? 'good' : 'danger',
        fields: [{
          title: '신청 유형',
          value: requestData.type,
          short: true,
        }, {
          title: '상태',
          value: requestData.status,
          short: true,
        }],
      }],
    };
    
    const response = await fetch(slackWebhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(slackPayload),
    });
    
    if (!response.ok) {
      throw new Error(`Slack API error: ${response.status}`);
    }
    
    return { success: true };
  } catch (error) {
    console.error('Slack notification error:', error);
    return { success: false, error: error.message };
  }
}
```

### Flutter Integration
```dart
// Trigger Slack notification from Flutter
Future<void> sendSlackNotification({
  required String userId,
  required String type,
  required String status,
  required String message,
}) async {
  try {
    await Supabase.instance.client.functions.invoke(
      'send_slack_notification_attendance',
      body: {
        'user_id': userId,
        'type': type,
        'status': status,
        'message': message,
      },
    );
  } catch (e) {
    print('Failed to send Slack notification: $e');
  }
}
```

## Location Services Integration

### GPS Configuration
```dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }
      
      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }
  
  static Future<bool> validateAttendanceLocation(
    double userLat, 
    double userLng,
  ) async {
    // Company office coordinates
    const double officeLat = 37.5665; // Example coordinates
    const double officeLng = 126.9780;
    const double allowedRadius = 100.0; // 100 meters
    
    double distance = Geolocator.distanceBetween(
      userLat, userLng,
      officeLat, officeLng,
    );
    
    return distance <= allowedRadius;
  }
}
```

### Attendance Validation
```dart
// Clock in with location validation
Future<void> clockInWithValidation() async {
  try {
    final position = await LocationService.getCurrentLocation();
    if (position == null) {
      throw Exception('위치 정보를 가져올 수 없습니다');
    }
    
    final isValidLocation = await LocationService.validateAttendanceLocation(
      position.latitude,
      position.longitude,
    );
    
    if (!isValidLocation) {
      throw Exception('출근 가능한 위치에 있지 않습니다');
    }
    
    // Proceed with clock in
    await clockIn(
      userId: userProvider.id!,
      lat: position.latitude,
      lng: position.longitude,
    );
    
    // Send confirmation notification
    await sendSlackNotification(
      userId: userProvider.id!,
      type: 'attendance',
      status: 'clock_in',
      message: '${userProvider.name}님이 출근하셨습니다.',
    );
  } catch (e) {
    print('Clock in error: $e');
    rethrow;
  }
}
```

## Error Handling & Retry Logic

### Network Error Handling
```dart
class ApiService {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  static Future<T> withRetry<T>(Future<T> Function() operation) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxRetries) {
          rethrow;
        }
        
        print('API call failed (attempt $attempt/$maxRetries): $e');
        await Future.delayed(retryDelay * attempt);
      }
    }
    
    throw Exception('Max retry attempts exceeded');
  }
}
```

### Offline Support
```dart
class OfflineQueueService {
  static final List<Map<String, dynamic>> _pendingOperations = [];
  
  static void queueOperation(Map<String, dynamic> operation) {
    _pendingOperations.add({
      ...operation,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Save to local storage
    _savePendingOperations();
  }
  
  static Future<void> processPendingOperations() async {
    if (_pendingOperations.isEmpty) return;
    
    final operations = List<Map<String, dynamic>>.from(_pendingOperations);
    _pendingOperations.clear();
    
    for (final operation in operations) {
      try {
        await _executeOperation(operation);
      } catch (e) {
        print('Failed to process pending operation: $e');
        // Re-queue if critical
        if (operation['critical'] == true) {
          _pendingOperations.add(operation);
        }
      }
    }
    
    await _savePendingOperations();
  }
}
```

## Security Best Practices

### API Key Management
```dart
// Environment-specific configuration
class Config {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qvhbigvdfyvhoegkhvef.supabase.co',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'default_key_for_development',
  );
}
```

### Request Validation
```dart
// Validate user permissions before API calls
Future<bool> canUserPerformAction(String action) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  
  final employee = await getEmployee(user.email!);
  if (employee == null) return false;
  
  final roles = employee['attendance_role'] as List<dynamic>?;
  
  switch (action) {
    case 'approve_leave':
      return roles?.contains('admin') == true || 
             roles?.contains('manager') == true;
    case 'view_all_attendance':
      return roles?.contains('admin') == true;
    default:
      return true; // Basic actions allowed for all users
  }
}
```

---

**Guide Version**: 1.0  
**Last Updated**: January 2025  
**API Compatibility**: Supabase v2.x, Firebase v11.x