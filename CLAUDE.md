# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 📝 Code Modification Reporting Guidelines

When making changes to the codebase, ALWAYS clearly indicate:

### Required Information for Each Change
1. **Layer**: Frontend (Flutter) or Backend (Supabase/Edge Functions)
2. **File Path**: Full path to the modified file
3. **Change Type**: Bug Fix, Feature Addition, Performance Optimization, Refactoring, etc.
4. **Impact Scope**: UI, Business Logic, Database, API, etc.

### Example Format
```
## 🔧 Changes Made

### Frontend (Flutter)
- **File**: `lib/providers/attendance_provider.dart`
- **Change**: Added auto clock-out at midnight for missing clock-outs
- **Impact**: Attendance tracking logic

### Backend (Supabase)
- **File**: `supabase/functions/validate_work_time/index.ts`
- **Change**: Fixed time validation logic
- **Impact**: API response for work time validation
```

## Project Overview

HANSL is a Flutter mobile application for attendance management and leave tracking for Korean company HANSL. The app integrates with Supabase for backend services and Firebase for push notifications.

## 📋 Version Management & Build Commands

### 🎯 올바른 버전 관리 명령어 패턴

#### 📈 **버전만 올리기**
```bash
"버전 올려줘"
"3.2.1로 버전 올려줘" 
"버전 업데이트 해줘"
```
→ **결과**: pubspec.yaml, iOS project, settings screen 버전만 수정

#### 🔨 **버전 올리고 + 빌드 + 업로드 + Git (권장)**
```bash
"버전 올리고 빌드해줘" ⭐️ 가장 효율적
"3.2.1로 버전 올리고 빌드해줘"
"버전 업하고 빌드 진행해줘"
```
→ **결과**: 
1. 버전 수정 (모든 파일)
2. APK/AAB 빌드
3. Google Drive 자동 업로드
4. 바탕화면 복사
5. Git 커밋 생성
6. 원격 저장소 푸시
7. 전체 상태 리포트

#### 📦 **빌드만 (버전 이미 올린 경우)**
```bash
"빌드해줘"
"빌드 진행해줘"
"APK/AAB 빌드해줘"
```
→ **결과**: 현재 버전으로 빌드 + 업로드만

#### 🚀 **Git 작업만**
```bash
"커밋 푸시해줘"
"커밋 푸시 진행해줘"
```
→ **결과**: 커밋 생성 + 원격 저장소 푸시만

### ✅ **자동화된 전체 프로세스 ("버전 올리고 빌드해줘")**
1. **Version Update**: pubspec.yaml, iOS Xcode project, settings screen
2. **Build Process**: APK (81MB) + AAB (58MB) 생성
3. **Auto Upload**: Google Drive 자동 업로드 (APK 스크립트 + AAB 동기화 폴더)
4. **Desktop Copy**: 바탕화면에 파일 복사
5. **Git Commit**: 상세한 커밋 메시지로 커밋 생성
6. **Git Push**: 원격 저장소에 푸시
7. **Status Report**: 전체 과정 완료 상태 리포트

## Common Development Commands

### Flutter App Development
```bash
flutter pub get                    # Install dependencies
flutter run                       # Run on connected device/emulator
flutter build apk --release       # Build release APK
flutter build appbundle --release # Build release AAB (for Play Store)
flutter test                      # Run tests
flutter analyze                   # Run static analysis (should show 0 warnings)
```

### 📦 Build & Upload Workflow
**When user requests build (빌드 해달라고 하면), automatically include upload process:**

#### 🚀 Automatic Build & Upload Process
```bash
# 1. Build both APK and AAB
flutter build apk --release       # For direct installation
flutter build appbundle --release # For Play Store submission

# 2. Generate versioned filenames with timestamp
VERSION="v3.0.1"  # Update version as needed
DATE=$(date +%Y%m%d_%H%M)
APK_NAME="hansl_${VERSION}_${DATE}.apk"
AAB_NAME="hansl_${VERSION}_${DATE}.aab"

# 3. Copy files with versioned names
cp build/app/outputs/flutter-apk/app-release.apk "$APK_NAME"
cp build/app/outputs/bundle/release/app-release.aab "$AAB_NAME"

# 4. Display build information
echo "📱 빌드 완료된 파일들:"
echo "- APK: $APK_NAME (일반 설치용)"
echo "- AAB: $AAB_NAME (Play Store 업로드용)"

# 5. Automatic Google Drive upload (APK + AAB)
GOOGLE_DRIVE_PATH="/Users/scott/Library/CloudStorage/GoogleDrive-hyeunung@gmail.com/내 드라이브/한슬_adroid_app"

# Try upload script first (for APK)
if [ -f "./upload_apk_to_drive.sh" ]; then
    echo "📤 APK 업로드 스크립트 실행 중..."
    ./upload_apk_to_drive.sh
else
    echo "⚠️ APK 업로드 스크립트 없음"
fi

# Upload AAB via Google Drive sync folder
if [ -d "$GOOGLE_DRIVE_PATH" ]; then
    echo "📤 AAB 파일 Google Drive 업로드 중..."
    cp "$AAB_NAME" "$GOOGLE_DRIVE_PATH/"
    if [ $? -eq 0 ]; then
        echo "✅ AAB 파일 Google Drive 업로드 완료!"
        echo "📂 위치: 한슬_adroid_app/$AAB_NAME"
    else
        echo "❌ AAB 파일 복사 실패"
    fi
else
    echo "📁 AAB 수동 업로드 필요: Google Drive 동기화 폴더 없음"
fi

# Copy both files to desktop for easy access
cp "$APK_NAME" ~/Desktop/ 2>/dev/null
cp "$AAB_NAME" ~/Desktop/ 2>/dev/null
echo "🖥️ 파일들을 바탕화면에도 복사 완료"

echo "✅ 업로드 프로세스 완료!"
echo "📊 최종 결과:"
echo "- APK: Google Drive + 바탕화면"
echo "- AAB: Google Drive + 바탕화면"
```

#### 🎯 Build Command Response Pattern
**When user says "빌드 해줘" or similar build requests:**
1. **Run full build process** (APK + AAB)
2. **Generate versioned filenames** with timestamp
3. **Automatically upload BOTH files to Google Drive** (APK via script, AAB via sync folder)
4. **Copy both files to desktop** for easy access
5. **Display final upload status** and file locations

#### 🚀 Version Update + Build + Git Pattern  
**When user says "버전 올리고 빌드해줘" or "X.X.X로 버전 올리고 빌드해줘":**
1. **Update version across ALL files** (pubspec.yaml, iOS project, settings screen)
2. **Run full build process** (APK + AAB)
3. **Generate versioned filenames** with timestamp
4. **Automatically upload BOTH files to Google Drive** (APK via script, AAB via sync folder)
5. **Copy both files to desktop** for easy access
6. **Commit all changes** with detailed commit message
7. **Push to remote repository**
8. **Display complete status** (version, build, upload, git)

#### 📋 Automatic Upload Process
- **APK**: Uses `./upload_apk_to_drive.sh` script (if available)
- **AAB**: Copies to Google Drive sync folder directly
- **Backup**: Both files copied to desktop
- **Verification**: Shows final upload status for both files

#### 📋 Upload Methods Available
- **gdrive CLI**: Automated upload via command line (preferred)
- **Google Drive Sync Folder**: Copy to synced folder path
- **Manual Upload**: Web interface instructions
- **Backup Scripts**: `./upload_apk_to_drive.sh` (existing script)

#### ⚠️ Important Build Notes
- **Always build both formats**: APK (direct install) + AAB (Play Store)
- **Version management**: Update version in pubspec.yaml before building
- **File naming**: Include version and timestamp for easy tracking
- **Upload verification**: Confirm successful upload with file listing
- **Storage management**: Archive old builds to free up space

### Supabase Local Development
```bash
cd supabase
supabase start                     # Start local Supabase instance (port 54321)
supabase db reset                  # Reset database with migrations and seed data
supabase functions serve          # Serve edge functions locally
supabase gen types dart > lib/types/supabase.dart  # Generate types
```

## Architecture Overview

### Core Architecture Pattern
- **MVC + Provider Pattern**: Uses Provider for state management
- **Services Layer**: Handles external API integrations
- **Multi-platform**: Supports Android, iOS, Web, Windows, macOS

### Key Integrations
- **Supabase**: Backend database, auth, edge functions
- **Firebase**: Push notifications via FCM
- **Location Services**: GPS-based attendance tracking

### Project Structure
```
lib/
├── main.dart                 # App entry point with provider setup
├── theme/                    # Design system (colors, fonts, shadows)
├── screens/                  # UI screens organized by feature
│   ├── splash/              # App launch screen
│   ├── auth/                # Login/authentication
│   ├── attendance/          # Clock in/out functionality  
│   ├── leave/               # Annual leave, business trips
│   ├── approval/            # Manager approval workflows
│   ├── calendar/            # Team/personal calendar
│   └── settings/            # User preferences
├── providers/               # State management (Provider pattern)
├── services/                # External API integrations
├── models/                  # Data models/classes
├── widgets/                 # Reusable UI components
├── utils/                   # Utility functions (including UserRoleHelper)
└── constants/               # App-wide constants

supabase/
├── functions/               # Edge functions (TypeScript/Deno)
└── migrations/              # Database schema changes
```

### Data Architecture

#### Annual Leave System
- **calculate_annual_leave**: Calculates granted annual leave for employees
- **update_used_annual_leave**: Updates used leave and calculates remaining leave
- **anniversary_check**: Grants 15 days leave after 12 months service
- **annual_year_update**: Resets annual leave for new year

#### Core Data Models
- **employees**: User management with roles
- **attendance**: GPS-tracked time entries
- **leave_requests**: Multi-step approval workflow
- **monthly_attendance**: Aggregated attendance data
- **purchase_requests**: Purchase order management
- **purchase_request_items**: Individual items in purchase orders

## Important Development Rules

### Problem-Solving Process (Critical)
**❌ Never immediately fix code when problems are reported**

**✅ Required Process:**
1. **Problem Analysis**: Understand current state and issues
2. **Root Cause Reporting**: Explain why problems occurred  
3. **Solution Proposal**: Present possible solutions
4. **User Confirmation**: Get approval before implementing
5. **Code Implementation**: Apply changes after approval

**🚀 Exception**: Skip analysis only when user explicitly says "바로 수정해줘", "즉시 적용해줘", "알아서 해줘"

### Database Migrations
- **Never modify existing migration files** - they may already be applied
- **Always create new migrations** for schema changes
- **Location**: `supabase/migrations/`  
- **Naming**: `00X_description.sql` or `YYYYMMDD_description.sql`

### Database Query Rules (Critical)
- **ALWAYS check table schema first**: Before ANY backend mapping, verify column existence
- **Never assume columns exist**: Check actual table structure, don't invent columns
- **User matching in purchase_requests**: Use `requester_name` field (NO `requester_email` field exists!)
- **Email-based matching for other tables**: Use email fields only where they actually exist
- **No foreign key relationships**: `purchase_requests` table has no FK to `employees`
- **Client-side filtering**: Filter after fetching data when direct joins not available
- **Verification Process**:
  1. Check Supabase table schema or migrations first
  2. Use ONLY existing columns in queries
  3. If column doesn't exist, DON'T add it without permission
- **Column Name Mapping Rules (매우 중요)**:
  1. **NEVER make up column names**: 절대로 컬럼명을 임의로 만들지 마세요
  2. **ALWAYS verify first**: 코딩 전에 반드시 실제 테이블 스키마 확인
  3. **Check migrations**: `supabase/migrations/` 파일 확인
  4. **Use exact column names**: 데이터베이스의 정확한 컬럼명만 사용
  5. **Don't assume similar names**: `item_name` vs `items_name`, `specification` vs `specifications` 등 추측 금지
- **Example**: 
  ```dart
  // ❌ WRONG - Don't use foreign key joins or non-existent columns
  .select('*, employees!purchase_requests_requester_id_fkey(...)')
  .select('*, some_column_i_think_exists')  // NO! Check first!
  .select('*, item_name, specifications')  // 추측한 컬럼명 사용 금지!
  
  // ✅ CORRECT - Use only verified columns
  .select('*')  // Or specific columns that actually exist
  // Then filter: item['requester_email'] == userEmail
  
  // ✅ CORRECT - 실제 확인된 컬럼명만 사용
  // 1. 먼저 마이그레이션 파일이나 스키마 확인
  // 2. 정확한 컬럼명 파악 (예: item_name이 아니라 items일 수도 있음)
  // 3. 확인된 컬럼명만 코드에 사용
  ```

### 🔑 User Matching Standards (사용자 매칭 표준)

#### 1. Primary User Identification
```dart
// 📌 현재 로그인 사용자 식별
final userEmail = _supabase.auth.currentUser?.email;  // 이메일로 식별
final employee = await _supabase.from('employees')
    .select()
    .eq('email', userEmail)  // employees 테이블은 email로 조회
    .single();
final userName = employee['name'];  // 이름 가져오기
```

#### 2. Purchase Request User Matching  
```dart
// 📌 purchase_requests 테이블 사용자 매칭
// ⚠️ IMPORTANT: purchase_requests 테이블에는 requester_email 컬럼이 없음!
// ✅ CORRECT: requester_name 필드 사용
final userName = employee['name'] as String;
.eq('requester_name', userName)  // 이름으로 필터링

// ❌ WRONG: requester_email 사용 금지 (존재하지 않는 컬럼)
.eq('requester_email', userEmail)  // 이런 컬럼 없음!
```

#### 3. Permission-based Display Rules
```dart
// 📌 입고대기 탭 - 권한별 표시 규칙
if (UserRoleHelper.isAppAdmin(purchaseRole)) {
  // app_admin: 모든 입고대기 항목 표시
  return allPendingReceipts;
} else if (UserRoleHelper.isFinalApprover(purchaseRole)) {
  // final_approver: 카테고리별 권한에 따라 표시
  return categoryFilteredReceipts;
} else {
  // 일반 사용자: 본인 요청 항목만 표시
  final userName = employee['name'];
  return receipts.where((r) => r['requester_name'] == userName);
}

// 📌 입고완료 버튼 표시 규칙
final currentUserName = userProvider.employee?['name'];
final requesterName = purchase['requester_name'];
if (UserRoleHelper.isAppAdmin(purchaseRole) || 
    UserRoleHelper.isPureLeadBuyer(purchaseRole) ||
    currentUserName == requesterName) {  // 본인 것만 처리 가능
  // 입고완료 버튼 표시
}
```

#### 4. Role-based Permission Checking
```dart
// 📌 권한 체크는 항상 UserRoleHelper 사용
import '../../utils/user_role_helper.dart';

// Purchase roles (구매 관련 권한) - 구매/발주/입고 관련
UserRoleHelper.isAppAdmin(purchaseRole)      // 모든 권한
UserRoleHelper.isPureLeadBuyer(purchaseRole) // lead buyer만
UserRoleHelper.isMiddleManager(purchaseRole) // 1차 승인자
UserRoleHelper.isFinalApprover(purchaseRole) // 최종 승인자

// Attendance roles (근태/연차 관련 권한) - 연차/출장 승인 관련
UserRoleHelper.isSuperAdmin(attendanceRole)  // 최고 관리자
UserRoleHelper.isAdmin(attendanceRole)       // 관리자
UserRoleHelper.isAnyManager(attendanceRole)  // 부서 매니저

// ⚠️ IMPORTANT: 역할 시스템 분리
// - 연차/출장 승인: attendance_role만 확인 (purchase_role 무관)
// - 구매/발주 승인: purchase_role만 확인 (attendance_role 무관)
// - 두 시스템은 완전히 독립적으로 운영됨
```

#### 5. Standard Field Names by Table
```dart
// 📌 테이블별 표준 필드명
// employees 테이블
- email: 사용자 이메일 (PRIMARY KEY)
- name: 사용자 이름
- purchase_role: 구매 권한 배열
- attendance_role: 근태 권한 배열

// purchase_requests 테이블
- requester_name: 요청자 이름 (NOT email!)
- requester_id: 요청자 ID (nullable, FK to employees)
- purchase_order_number: 발주번호
- vendor_name: 공급업체명
- payment_category: 카테고리 ('발주', '구매 요청')

// purchase_request_items 테이블
- requester_name: 요청자 이름 (denormalized)
- item_name: 품목명 (NOT items_name!)
- specification: 규격 (NOT specifications!)
```

### Environment Configuration
- **Environment variables**: Uses `.env` file (not committed)
- **Required vars**: `SUPABASE_URL`, `SUPABASE_ANON_KEY` 
- **Korean timezone**: All time-related functionality uses Korea time (UTC+9)
- **Multi-platform**: Same codebase runs on Android, iOS, Web, macOS, Windows

## User Role Management (중요)
- **UserRoleHelper 클래스 사용**: `lib/utils/user_role_helper.dart`에 모든 역할 체크 로직 중앙화
- **역할 체크시 반드시 UserRoleHelper 메서드 사용**
  - `UserRoleHelper.isAppAdmin(roles)` - app_admin 확인
  - `UserRoleHelper.isLeadBuyer(roles)` - lead buyer 확인 (app_admin 제외)
  - `UserRoleHelper.isRegularEmployee(roles)` - 일반 직원 확인
  - `UserRoleHelper.hasPurchaseApprovalAuth(roles)` - 발주 승인 권한 확인
  - `UserRoleHelper.hasAnyPurchaseRole(roles)` - 발주 관련 역할 확인
  - `UserRoleHelper.isMiddleManager(roles)` - 중간 관리자 확인
  - `UserRoleHelper.isFinalApprover(roles)` - 최종 승인자 확인
- **절대 직접 문자열로 역할 체크하지 말 것**: `roles.contains('app_admin')` ❌
- **UserRoleHelper를 다시 생성하지 말 것**: 이미 존재함
- **🚨 두 가지 독립적인 역할 시스템**:
  - **attendance_role**: 연차/출장 승인, 근태 관리용
  - **purchase_role**: 구매/발주/입고 관리용
  - 두 시스템은 완전히 독립적 - 서로 영향 없음

## Code Quality Standards (2025년 1월 25일 기준)
- **Flutter Analyze**: 0 warnings 유지
- **Production 빌드에 디버깅 코드 포함 금지**:
  - `kDebugMode` 조건문 사용 금지
  - `print()`, `debugPrint()` 문 사용 금지
  - `AppLogger`, `Logger`, `_log()` 등 디버깅 로그 함수 사용 금지
- **사용하지 않는 코드 제거**:
  - Unused variables
  - Unused imports
  - Dead code
  - Commented out code (필요시만 유지)
- **Null Safety 준수**:
  - 불필요한 null 체크 제거
  - Nullable 타입 적절히 처리

## 📦 Version Management Workflow

### 🚀 Complete Version Update Process
**When user says "버전 올리고 빌드해줘" or "버전 업 빌드 해줘" - Full automation including Git commit & push!**

#### Step 1: Version Update Across All Files
```bash
# Update version in all platform-specific files
# 1. pubspec.yaml
version: [NEW_VERSION]+[BUILD_NUMBER]  # e.g., 3.1.0+245

# 2. iOS Xcode project settings (for Xcode archive compatibility)
# File: ios/Runner.xcodeproj/project.pbxproj
MARKETING_VERSION = [VERSION];        # e.g., 3.1.0
CURRENT_PROJECT_VERSION = [BUILD];    # e.g., 245

# 3. Settings screen fallback version
# File: lib/screens/settings/settings_screen.dart
_appVersion = '앱 버전 [VERSION]+[BUILD]';  # e.g., 앱 버전 3.1.0+245

# 4. Android automatically inherits from pubspec.yaml via flutter.versionCode/flutter.versionName
```

#### Step 2: Build & Test Process
```bash
# 1. Build both APK and AAB
flutter build apk --release           # For direct installation  
flutter build appbundle --release     # For Play Store submission

# 2. Generate versioned filenames with timestamp
VERSION="v3.1.0"  # Use updated version
DATE=$(date +%Y%m%d_%H%M)
APK_NAME="hansl_${VERSION}_${DATE}.apk"
AAB_NAME="hansl_${VERSION}_${DATE}.aab"

# 3. Copy files with versioned names
cp build/app/outputs/flutter-apk/app-release.apk "$APK_NAME"
cp build/app/outputs/bundle/release/app-release.aab "$AAB_NAME"

# 4. Verify build information
echo "📱 빌드 완료된 파일들:"
echo "- APK: $APK_NAME (일반 설치용)"
echo "- AAB: $AAB_NAME (Play Store 업로드용)"
ls -lh "$APK_NAME" "$AAB_NAME"
```

#### Step 3: Git Branch Name Update (CRITICAL)
```bash
# 🚨 IMPORTANT: 버전 업데이트 시 브랜치 이름도 반드시 동기화 필요
OLD_VERSION="3.1.3"  # 이전 버전
NEW_VERSION="3.1.4"  # 새 버전

# 1. 로컬 브랜치 이름 변경
git branch -m main-v${OLD_VERSION} main-v${NEW_VERSION}

# 2. 새 브랜치 푸시
git push origin main-v${NEW_VERSION}

# 3. GitHub 기본 브랜치 변경
gh repo edit --default-branch main-v${NEW_VERSION}

# 4. 구 브랜치 삭제
git push origin --delete main-v${OLD_VERSION}

# 5. 로컬 원격 추적 브랜치 정리
git remote prune origin

echo "✅ 브랜치 이름이 버전과 동기화되었습니다!"
```

#### Step 4: Automatic Google Drive Upload
```bash
# Automatic Google Drive upload (APK + AAB)
GOOGLE_DRIVE_PATH="/Users/scott/Library/CloudStorage/GoogleDrive-hyeunung@gmail.com/내 드라이브/한슬_adroid_app"

# Upload APK via script (if available)
if [ -f "./upload_apk_to_drive.sh" ]; then
    echo "📤 APK 업로드 스크립트 실행 중..."
    ./upload_apk_to_drive.sh
else
    echo "⚠️ APK 업로드 스크립트 없음"
fi

# Upload AAB via Google Drive sync folder
if [ -d "$GOOGLE_DRIVE_PATH" ]; then
    echo "📤 AAB 파일 Google Drive 업로드 중..."
    cp "$AAB_NAME" "$GOOGLE_DRIVE_PATH/"
    if [ $? -eq 0 ]; then
        echo "✅ AAB 파일 Google Drive 업로드 완료!"
        echo "📂 위치: 한슬_adroid_app/$AAB_NAME"
    else
        echo "❌ AAB 파일 복사 실패"
    fi
else
    echo "📁 AAB 수동 업로드 필요: Google Drive 동기화 폴더 없음"
fi

# Copy both files to desktop for easy access
cp "$APK_NAME" ~/Desktop/ 2>/dev/null
cp "$AAB_NAME" ~/Desktop/ 2>/dev/null
echo "🖥️ 파일들을 바탕화면에도 복사 완료"

echo "✅ 버전 업데이트 및 업로드 프로세스 완료!"
echo "📊 최종 결과:"
echo "- APK: Google Drive + 바탕화면"
echo "- AAB: Google Drive + 바탕화면"
```

#### Step 5: Automatic Git Commit & Push 
```bash
# Git status check and commit preparation
git status                        # Check all changes
git diff                         # Review changes  
git log --oneline -n 5           # Check recent commits for style

# Add all version update files and create commit with current version
git add pubspec.yaml ios/Runner.xcodeproj/project.pbxproj lib/screens/settings/settings_screen.dart

git commit -m "$(cat <<'EOF'
chore: 버전 [CURRENT_VERSION] 업데이트

- pubspec.yaml: version [CURRENT_VERSION]+[BUILD_NUMBER]
- iOS 프로젝트: MARKETING_VERSION [CURRENT_VERSION], CURRENT_PROJECT_VERSION [BUILD_NUMBER]
- 설정 화면: 폴백 버전 표시 [CURRENT_VERSION] 업데이트
- APK/AAB 빌드 완료 및 Google Drive 업로드 완료

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Push to current branch 
git push

echo "✅ 버전 [CURRENT_VERSION] Git 커밋 및 푸시 완료!"
echo "📂 브랜치: $(git branch --show-current)"
```

#### Step 6: Complete Status Report
```bash
echo "🎯 HANSL v{VERSION} 전체 릴리즈 완료!"
echo "========================="
echo "📱 새 버전: v{VERSION}+{BUILD}"
echo "📁 파일명: hansl_v{VERSION}_{TIMESTAMP}.apk/aab"
echo "📊 크기: APK 81MB / AAB 58MB"
echo "⏰ 빌드 시간: {TIMESTAMP}"
echo ""
echo "🔧 주요 변경사항:"
echo "- [변경사항 요약]"
echo ""
echo "✅ 완료된 작업:"
echo "- ✅ 버전 업데이트 (4개 파일)"
echo "- ✅ APK/AAB 빌드 완료"
echo "- ✅ Google Drive 자동 업로드"
echo "- ✅ 바탕화면 파일 복사"
echo "- ✅ Git 커밋 (현재 버전명)"
echo "- ✅ 원격 저장소 푸시 완료"
```

#### 🎯 **"버전 업 빌드 해줘" 명령어 = 전체 자동화**
- **Step 1**: 버전 업데이트 (4개 파일)
- **Step 2**: APK/AAB 빌드 (2개 파일)  
- **Step 3**: Git 브랜치 동기화 (버전별)
- **Step 4**: Google Drive 업로드 (자동)
- **Step 5**: Git 커밋 & 푸시 (현재 버전명으로)
- **Step 6**: 완료 상태 리포트

#### 💡 **가장 효율적인 명령어**
```bash
"3.2.1로 버전 올리고 빌드해줘"  ⭐️ 권장
```
→ 버전 명시 + 전체 자동화 프로세스 (빌드 + 업로드 + Git)

#### 🎯 Files That Must Be Updated for Version Changes
1. **pubspec.yaml** - Main version source (Flutter uses this)
2. **ios/Runner.xcodeproj/project.pbxproj** - iOS version (MARKETING_VERSION & CURRENT_PROJECT_VERSION)
3. **lib/screens/settings/settings_screen.dart** - Fallback version display
4. **android/app/build.gradle.kts** - Already references Flutter version automatically

#### ⚠️ Critical Version Update Rules
- **Always update ALL 4 files** - pubspec.yaml, iOS project, settings fallback, Android auto-inherits
- **🚨 MANDATORY: Git Branch Name Sync** - 버전 변경 시 브랜치 이름도 반드시 동기화 (main-v3.1.4 형태)
- **Xcode Archive Compatibility** - iOS project settings must match pubspec.yaml exactly
- **Build & Test** - Always build both APK and AAB after version update
- **Automatic Upload** - Both files automatically uploaded to Google Drive
- **Verification** - Confirm version appears correctly in built APK/AAB

#### 📋 Version Update Checklist
- [ ] Update pubspec.yaml version
- [ ] Update iOS Xcode project MARKETING_VERSION & CURRENT_PROJECT_VERSION (6 locations each)
- [ ] Update settings screen fallback version
- [ ] 🚨 **Git Branch Name Update** (main-v[VERSION] 형태로 동기화)
- [ ] Build APK and AAB
- [ ] Generate timestamped filenames
- [ ] Upload both files to Google Drive
- [ ] Copy files to desktop
- [ ] Verify version in built files

## Testing and Quality
- **Static Analysis**: `flutter analyze` with `flutter_lints` package (0 warnings)
- **Widget Tests**: Located in `test/` directory using `flutter_test`
- **Manual Testing**: Test on multiple platforms before release
- **Build Verification**: Ensure release APK builds successfully
- **Push Notification Testing**: Always use `test@hansl.com` account for all push notification tests (no other test accounts)

## Key Service Integrations

### Supabase Edge Functions
All backend business logic runs in Supabase edge functions (Deno/TypeScript):
- Authentication and authorization
- Annual leave calculations
- Attendance validation
- FCM push notifications

### Firebase Setup
- **FCM**: Push notifications for leave approvals, attendance reminders
- **Multi-platform**: Configured for iOS (`GoogleService-Info.plist`) and Android (`google-services.json`)
- **Firebase Service Account Keys**: Firebase 서비스 계정 키는 만료되지 않고 유효합니다! 수동으로 삭제하지 않는 한 만료되지 않습니다

### 🚨 Firebase 서비스 계정 키 관리 규칙 (Critical - 2025년 10월 11일 사고 방지)
**환경변수 손상 방지를 위한 필수 지침**

#### ❌ 절대 하지 말아야 할 것:
```bash
# 위험: 직접 cat으로 환경변수 설정 (줄바꿈 손상 위험)
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat firebase.json)"

# 위험: Dashboard에서 복사/붙여넣기 (자동 포맷팅으로 손상)
# Supabase Dashboard → Settings → Secrets에서 직접 입력 금지
```

#### ✅ 올바른 Firebase 키 설정 방법:
```bash
# 1. 새 키 생성 시 (Firebase Console에서)
#    - JSON 형식 선택
#    - 파일명: hansl-attendance-firebase-adminsdk.json

# 2. 환경변수 설정 (반드시 이 방법 사용!)
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat hansl-attendance-firebase-adminsdk.json)" --project-ref qvhbigvdfyvhoegkhvef

# 3. 즉시 테스트 (필수!)
node test_fcm_final.js  # 또는 ./test_fcm_detailed.sh
```

#### 🔍 문제 발생 시 진단 방법:
```javascript
// JWT Signature 에러가 발생하면:
// 1. 로컬 파일 정상 여부 확인
cat hansl-attendance-firebase-adminsdk.json | jq .  // JSON 파싱 되면 정상

// 2. 새 키 생성 및 교체
// Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성

// 3. 환경변수 재설정 (위의 올바른 방법 사용)
```

#### 📊 사고 이력:
- **2025년 10월 11일**: 환경변수 저장 시 Private Key 손상으로 JWT 서명 실패
- **원인**: 이스케이프 처리 문제로 `\n`이 `\\n`으로 변환됨
- **해결**: 새 키 생성 후 올바른 방법으로 재설정

### Location Services
- **GPS Tracking**: Uses `geolocator` package for attendance verification
- **Validation**: Server-side location validation via edge functions

## Security Considerations
- **RLS Policies**: All database tables use Row Level Security
- **JWT Authentication**: Supabase JWT tokens for API access
- **Role-based Access**: Different permissions for employees, managers, admins (UserRoleHelper 사용)
- **Environment Secrets**: API keys stored in environment variables, not code
- **No Debug Logs in Production**: 민감한 정보가 로그에 노출되지 않도록 관리

## Performance Notes
- **Provider Pattern**: Efficient state management with selective rebuilds
- **Image Assets**: Optimized icons and splash screens for all platforms
- **Bundle Size**: Uses tree shaking and code splitting
- **Offline Capability**: Caches essential data locally
- **Clean Code**: 불필요한 디버깅 코드 제거로 런타임 성능 향상

## Recent Refactoring (2025년 1월 25일)
- **UserRoleHelper 중앙화**: 모든 역할 체크 로직을 하나의 클래스로 통합
- **Provider 최적화**: 중복 함수 제거, 사용하지 않는 변수 정리
- **Flutter Analyze 경고 해결**: 277개 → 0개
- **디버깅 코드 완전 제거**: 1,600+ 라인의 디버깅 코드 제거
- **빌드 최적화**: Release APK 크기 최적화 (84.4MB)

## 필수 리팩토링 규칙 (2025년 1월 25일 확립)

### UserRoleHelper 패턴 (중앙화된 역할 관리)
```dart
// ❌ WRONG - 직접 문자열로 역할 체크
if (roles.contains('app_admin') || roles.contains('lead_buyer')) { ... }
if (purchaseRoles.any((r) => r == 'middle_manager')) { ... }

// ✅ CORRECT - UserRoleHelper 사용
if (UserRoleHelper.isAppAdmin(roles)) { ... }
if (UserRoleHelper.hasPurchaseApprovalAuth(purchaseRoles)) { ... }
```

### Provider 중복 제거 패턴
```dart
// ❌ WRONG - 동일한 로직의 함수가 여러 개
Future<void> _sendNotification() { ... }
Future<void> _sendPurchaseNotification() { ... }  // 거의 동일한 내용

// ✅ CORRECT - 하나의 통합 함수로
Future<void> _sendPurchaseApprovalNotification({
  required String status,
  required bool isMiddleManager,
  ...
}) { ... }
```

### 디버깅 코드 완전 제거 규칙
```dart
// ❌ WRONG - Production 코드에 디버깅 코드 포함
if (kDebugMode) {
  print('디버깅 정보: $data');
}
debugPrint('상태 변경: $status');
// Debug code removed (주석만 남김)

// ✅ CORRECT - Production에는 디버깅 코드 없음
// 필요시 별도 로깅 서비스 사용
```

### Nullable 파라미터 처리 패턴
```dart
// ❌ WRONG - nullable을 non-nullable로 바로 전달
String? paymentCategory = data['payment_category'];
someFunction(paymentCategory: paymentCategory); // Error!

// ✅ CORRECT - null coalescing 사용
someFunction(paymentCategory: paymentCategory ?? '');
```

### Import 정리 규칙
```dart
// ❌ WRONG - 사용하지 않는 import
import 'package:flutter/foundation.dart'; // kDebugMode만 사용했는데 제거 후 남음
import '../screens/purchase/purchase_management_screen.dart'; // 파일 자체가 없음

// ✅ CORRECT - 실제 사용하는 import만 유지
// flutter analyze로 확인
```

### 중복 함수 제거 및 Wrapper 패턴
```dart
// ❌ WRONG - main.dart에 중복 함수
Future<void> _initializeServices() { ... }
Future<void> _initializeServices() { ... }  // 동일한 이름의 함수 2개

// ✅ CORRECT - 하나만 유지하거나 wrapper 함수 활용
Future<void> _initializeServices() { 
  await _initializeBaseServices();
  await _initializeOptionalServices();
}
```

## 리팩토링 Best Practices

### 대규모 코드 정리 패턴
1. **단계별 접근**: 한번에 모든 것을 수정하지 말고 카테고리별로 처리
   - 먼저 간단한 경고부터 해결 (unused variables, imports)
   - 다음 복잡한 구조적 문제 해결
   - 마지막으로 전체 디버깅 코드 제거
2. **빌드 확인**: 각 단계마다 빌드 성공 여부 확인
3. **Git 백업**: 큰 변경 전 커밋하여 롤백 가능하게 준비

### Sub-Agent 사용 교훈
- **Sub-Agent 효과적인 경우**: 
  - 단순 반복 작업 (unused variables 제거)
  - 독립적 파일 수정
  - 패턴이 명확한 작업
- **Sub-Agent 피해야 할 경우**:
  - 복잡한 로직 변경
  - 의존성이 있는 파일 수정
  - 구조적 리팩토링
- **실패시 대처**: `git checkout HEAD -- [파일경로]`로 즉시 복구

### 코드 중복 제거 원칙 (DRY)
1. **중복 패턴 식별**: 동일한 로직이 2번 이상 반복되면 함수화
2. **중앙화 위치 선정**:
   - 역할 체크 → UserRoleHelper 클래스
   - API 호출 → Service 클래스
   - UI 컴포넌트 → Widgets 폴더
3. **Wrapper 함수 활용**: 기존 코드 호환성 유지하며 점진적 마이그레이션

### 경고 해결 우선순위
1. **즉시 해결 필수**: 
   - Syntax errors
   - Type mismatches
   - Missing required parameters
2. **리팩토링과 함께**: 
   - Unused code
   - Dead code
   - Unnecessary null checks
3. **스타일 가이드**: 
   - Naming conventions
   - Formatting issues

### 디버깅 코드 관리
- **개발 중**: `kDebugMode`로 감싸서 사용
- **배포 전**: 모든 디버깅 코드 완전 제거
- **대체 방법**: 
  - Error tracking service (Sentry, Crashlytics)
  - Analytics for production insights
  - Structured logging with levels

### 파일 손상 복구 절차
1. **즉시 중단**: 에러 발견시 추가 수정 중단
2. **Git 상태 확인**: `git status`로 변경 파일 확인
3. **파일 복구**: `git checkout HEAD -- [손상된 파일 경로]`
4. **재시도**: 수동으로 신중하게 재수정

### 성능 최적화 체크리스트
- [ ] 불필요한 import 제거
- [ ] 사용하지 않는 변수/함수 제거
- [ ] 중복 코드 제거
- [ ] 디버깅 코드 제거
- [ ] Widget rebuild 최소화
- [ ] 이미지 최적화
- [ ] Tree shaking 확인

## 실제 리팩토링 사례 (2025년 1월 25일)

### 1. PurchaseProvider 정리
```dart
// Before: 중복 함수 2개
Future<void> _sendPurchaseApprovalNotification() { ... }
Future<void> _sendPurchaseNotification() { ... } // 90% 동일

// After: 통합된 1개 함수
Future<void> _sendPurchaseApprovalNotification({
  required String status,
  required bool isMiddleManager,
  String? rejectionReason,
}) { 
  // status에 따라 분기 처리
}
```

### 2. MainTab isPureLeadBuyer 수정
```dart
// Before: 직접 역할 체크
final isLeadBuyer = purchaseRoles.contains('lead buyer') && 
                    !purchaseRoles.contains('app_admin');

// After: UserRoleHelper 사용
final isLeadBuyer = UserRoleHelper.isPureLeadBuyer(purchaseRoles);
```

### 3. 불필요한 null 체크 제거 (4개)
```dart
// Before: Non-nullable에 대한 불필요한 체크
if (nonNullableVar != null) { ... }

// After: 체크 제거
// nonNullableVar 직접 사용
```

### 4. 사용하지 않는 변수 제거 (45개)
```dart
// Before: 선언만 하고 사용 안함
final unused = someCalculation();
int counter = 0;  // never used

// After: 완전 제거 또는 _ prefix 사용
// 제거됨
```

### 5. kDebugMode 패턴 완전 제거 (1,600+ 라인)
```dart
// Before: 모든 파일에 산재
if (kDebugMode) {
  print('=== 출근 처리 시작 ===');
  print('위치: $latitude, $longitude');
}

// After: 완전 제거
// Production에서는 로깅 서비스 사용
```