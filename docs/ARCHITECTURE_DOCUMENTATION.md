# HANSL Flutter App - Architecture Documentation

## Overview
HANSL is a comprehensive Flutter mobile application for attendance management and leave tracking, designed for Korean company HANSL. The app integrates with multiple backend services and supports multi-platform deployment.

## System Architecture

### Application Layer Structure
```
┌─────────────────────────────────────────┐
│                HANSL App                │
├─────────────────────────────────────────┤
│              UI Layer                   │
│  ├── Screens (Feature-based routing)    │
│  ├── Widgets (Reusable components)      │
│  └── Theme (Design system)              │
├─────────────────────────────────────────┤
│           Business Logic                │
│  ├── Providers (State management)       │
│  ├── Services (External integrations)   │
│  └── Utils (Helper functions)           │
├─────────────────────────────────────────┤
│            Data Layer                   │
│  ├── Models (Data structures)           │
│  ├── Constants (App-wide values)        │
│  └── Types (TypeScript definitions)     │
└─────────────────────────────────────────┘
```

### Core Design Patterns

#### 1. Provider Pattern (State Management)
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => UserProvider()),
    ChangeNotifierProvider(create: (_) => LeaveProvider()),
    ChangeNotifierProvider(create: (_) => FontProvider()),
    ChangeNotifierProxyProvider<UserProvider, AttendanceProvider>(...),
  ],
  child: MaterialApp(...),
)
```

**Benefits**:
- Reactive UI updates
- Centralized state management
- Dependency injection
- Memory efficient rebuilds

#### 2. Service Layer Architecture
```dart
// External service integrations
├── EnvironmentService     // Configuration management
├── NotificationService    // Firebase push notifications
├── SlackService          // Team communication
├── PerformanceService    // Monitoring and optimization
└── SecureStorageService  // Encrypted local storage
```

#### 3. Responsive Design System
```dart
class ResponsiveUtils {
  static double getScaleFactor(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    final baseWidth = 440.0; // iPhone 16 Pro Max 기준
    
    double scale = screenWidth / baseWidth;
    
    // Platform-specific adjustments
    if (!kIsWeb && Platform.isAndroid) {
      scale *= 0.92; // Android에서 8% 작게
    }
    
    return scale.clamp(0.8, 1.2);
  }
}
```

## Feature Modules

### 1. Authentication Module
**Location**: `lib/screens/auth/`

**Components**:
- `LoginScreen`: User authentication with Supabase
- `SignupScreen`: New user registration
- Custom splash screen with 1.5-second display

**Flow**:
```
App Launch → Native Splash → Custom Splash (1.5s) → Auth Check
    ↓
Session Valid? → Yes → MainTab (Auto-login)
              → No  → LoginScreen
```

**Key Features**:
- Supabase JWT authentication
- Auto-login with session persistence
- "Remember Me" and "Save ID" options
- Password reset functionality

### 2. Attendance Module
**Location**: `lib/screens/attendance/`

**Components**:
- `AttendanceScreen`: Clock in/out interface
- GPS-based location verification
- Real-time attendance tracking

**Integration**:
```dart
// GPS verification
final position = await Geolocator.getCurrentPosition();
// Backend validation via Supabase edge function
await Supabase.instance.client.functions.invoke('validate_attendance', body: {...});
```

### 3. Leave Management Module
**Location**: `lib/screens/leave/`

**Components**:
- `LeaveStatusScreen`: Personal leave overview
- Annual leave calculation and tracking
- Business trip management

**Leave Types**:
- `annual`: Full day annual leave
- `half_am`: Morning half-day leave
- `half_pm`: Afternoon half-day leave
- `official`: Official leave
- `biztrip`: Business trip

### 4. Approval Workflow Module
**Location**: `lib/screens/approval/`

**Components**:
- `ApprovalScreen`: Manager approval interface
- Role-based access control
- Multi-step approval process

**Permissions**:
```dart
// Admin: All approvals
final bool isAdmin = attendanceRole?.contains('admin') ?? false;

// Manager: Department-specific approvals
final Map<String, List<String>> managerDepartments = {
  '양승진': ['개발1팀', '개발2팀'],
  '최창열': ['개발3팀'],
  '이정화': ['CAD'],
  // ...
};
```

### 5. Calendar Module
**Location**: `lib/screens/calendar/`

**Components**:
- Team calendar view
- Personal schedule management
- Leave request visualization

## Backend Integration

### Supabase Architecture
```
┌─────────────────────────────────────────┐
│              Supabase                   │
├─────────────────────────────────────────┤
│  Database (PostgreSQL with RLS)        │
│  ├── employees (User management)        │
│  ├── attendance (Time tracking)         │
│  ├── leave_requests (Leave management)  │
│  └── monthly_attendance (Aggregated)    │
├─────────────────────────────────────────┤
│  Edge Functions (Deno/TypeScript)       │
│  ├── calculate_annual_leave             │
│  ├── update_used_annual_leave           │
│  ├── send_slack_notification            │
│  └── validate_attendance                │
├─────────────────────────────────────────┤
│  Authentication (JWT + RLS)             │
│  └── Row Level Security policies        │
└─────────────────────────────────────────┘
```

### Firebase Integration
```dart
// Push notification setup
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
await NotificationService.initialize();
```

**Features**:
- Cross-platform push notifications
- Background message handling
- Deep linking support

### Slack Integration
```typescript
// Supabase Edge Function
const slackResponse = await fetch(slackWebhookUrl, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    channel: userSlackId,
    text: notificationMessage,
  }),
});
```

## Data Models

### Core Entities

#### Employee Model
```dart
class Employee {
  final String id;
  final String name;
  final String email;
  final String department;
  final String role;
  final List<String> attendanceRole;
  final String? slackId;
  final DateTime joinDate;
}
```

#### Leave Request Model
```dart
class LeaveRequest {
  final String id;
  final String userId;
  final String type; // annual, half_am, half_pm, official, biztrip
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // pending, approved, rejected
  final String? destination; // for business trips
  final DateTime createdAt;
}
```

#### Attendance Record Model
```dart
class AttendanceRecord {
  final String id;
  final String userId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final double? latitude;
  final double? longitude;
  final String status; // present, absent, late
}
```

## Security Architecture

### Authentication & Authorization
```dart
// JWT Token validation
final session = Supabase.instance.client.auth.currentSession;
if (session?.accessToken != null) {
  // User authenticated
}

// Role-based access control
final userRole = userProvider.employee?['attendance_role'];
final canApprove = userRole?.contains('admin') ?? false;
```

### Data Protection
- **Row Level Security (RLS)**: Database-level access control
- **JWT Authentication**: Secure token-based authentication
- **Encrypted Storage**: Sensitive data encrypted locally
- **HTTPS Only**: All API communications encrypted

### Privacy Compliance
```dart
// Location data handling
await Geolocator.requestPermission();
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);
// Location used only for attendance verification
```

## Performance Optimization

### Caching Strategy
```dart
class PerformanceInitialization {
  static final Map<String, dynamic> _cache = {};
  static Timer? _cleanupTimer;
  
  static void enablePerformanceMonitoring() {
    _cleanupTimer = Timer.periodic(
      Duration(minutes: 10),
      (_) => performMaintenance(),
    );
  }
}
```

### Widget Optimization
```dart
class OptimizedConsumer<T extends ChangeNotifier> extends StatefulWidget {
  final String componentKey;
  final Duration throttleDuration;
  final bool Function(T) shouldRebuild;
  final Widget Function(BuildContext, T, Widget?) builder;
}
```

### Bundle Optimization
- **Tree Shaking**: Unused code elimination
- **Code Splitting**: Feature-based code splitting
- **Asset Optimization**: Compressed images and fonts
- **Platform-specific Builds**: iOS/Android optimizations

## Multi-Platform Support

### Supported Platforms
```yaml
platforms:
  - ios: "Primary platform, fully tested"
  - android: "Secondary platform, core features"
  - web: "Limited functionality, admin interface"
  - macos: "Desktop support for managers"
  - windows: "Desktop support for administrators"
```

### Platform-Specific Features
```dart
// iOS-specific optimizations
if (Platform.isIOS) {
  return CupertinoPageRoute(builder: (_) => destination);
}

// Web compatibility
if (kIsWeb) {
  return WebSpecificWidget();
}
```

## Testing Strategy

### Test Coverage
```
├── Unit Tests (lib/test/)
│   ├── Provider logic testing
│   ├── Service integration testing
│   └── Utility function testing
├── Widget Tests
│   ├── Screen rendering tests
│   ├── User interaction tests
│   └── State management tests
└── Integration Tests
    ├── Authentication flow
    ├── Attendance workflow
    └── Leave approval process
```

### Quality Assurance
```bash
# Static analysis
flutter analyze

# Unit testing
flutter test

# Build verification
flutter build apk --release
flutter build ios --release
```

## Deployment Architecture

### Build Configuration
```yaml
# pubspec.yaml
version: 1.1.0+9
environment:
  sdk: ^3.8.0

# Multi-platform builds
flutter build apk --release           # Android
flutter build ios --release           # iOS
flutter build web --release           # Web
flutter build macos --release         # macOS
flutter build windows --release       # Windows
```

### Environment Management
```dart
// Production configuration
await Supabase.initialize(
  url: 'https://qvhbigvdfyvhoegkhvef.supabase.co',
  anonKey: 'production_anon_key',
);

// Firebase configuration per platform
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

---

**Documentation Version**: 2.0  
**Last Updated**: January 2025  
**Flutter SDK**: 3.8.0  
**Dart SDK**: 3.2.0+