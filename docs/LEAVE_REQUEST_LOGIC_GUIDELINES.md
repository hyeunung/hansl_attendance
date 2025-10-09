# 연차/출장 신청 로직 필터 지침서

> **중요**: 이 문서는 연차/출장 알림 시스템의 핵심 로직과 필터를 정의합니다.  
> 파일을 새로 만들거나 시스템을 재구성할 때 이 내용을 그대로 적용하세요.

## 🎯 **1. 신청 시 알림 로직 (3단계 분류)**

### **1-1. SuperAdmin 신청** 👑
- **신청자**: 정현웅 (`hyun-woong.jeong@hansl.com`)
- **조건**: `userEmail == AppStrings.adminEmail`
- **알림 대상**: **본인에게만** 확인 알림
- **알림 내용**: 
  - 제목: "✅ {연차/출장} 신청 완료"
  - 내용: "귀하의 {연차/출장} 신청이 접수되었습니다.\n기간: {기간}"
- **구현 코드**:
  ```dart
  final isSuperAdmin = userEmail == AppStrings.adminEmail;
  if (isSuperAdmin) {
    // SuperAdmin 신청 → 본인에게 확인 알림 전송
    await NotificationService.sendNotificationToAdmins(
      title: '✅ $typeLabel 신청 완료',
      body: '귀하의 $typeLabel 신청이 접수되었습니다.\n기간: $period',
      data: {
        'type': type == 'biztrip' ? 'business_trip' : 'leave_request',
        'requester_name': name,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'leave_type': type,
        'requester_is_superadmin': 'true',
      },
      requesterDepartment: department,
      isManagerRequest: false,
    );
  }
  ```

### **1-2. Manager 신청** 🏢
- **신청자**: 5명의 부서 관리자
  - 양승진 (개발1팀, 개발2팀 관리)
  - 최창열 (개발3팀 관리)
  - 조근일 (연구소 관리)
  - 황연순 (경영지원팀 관리)
  - 이정화 (CAD 관리)
- **조건**: `AppStrings.managerNames.contains(name)`
- **알림 대상**: **SuperAdmin에게만** 알림
- **알림 내용**:
  - 제목: "👑 Manager {연차/출장} 신청"
  - 내용: "{이름} 매니저님이 {연차/출장}을 신청했습니다.\n기간: {기간}"
- **구현 코드**:
  ```dart
  final isManager = AppStrings.managerNames.contains(name);
  if (isManager) {
    // Manager 신청 → SuperAdmin에게만 알림
    await NotificationService.sendNotificationToAdmins(
      title: '👑 Manager $typeLabel 신청',
      body: '$name 매니저님이 $typeLabel을 신청했습니다.\n기간: $period',
      data: {
        'type': type == 'biztrip' ? 'business_trip' : 'leave_request',
        'requester_name': name,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'leave_type': type,
        'requester_is_manager': 'true',
      },
      requesterDepartment: department,
      isManagerRequest: true,
    );
  }
  ```

### **1-3. 일반직원 신청** 👤
- **신청자**: 24명의 일반직원
- **조건**: SuperAdmin도 Manager도 아닌 경우
- **알림 대상**: **SuperAdmin + 해당 부서 Manager만** *(Admin 제외)*
- **알림 내용**:
  - 제목: "📝 새로운 {연차/출장} 신청"
  - 내용: "{이름}님이 {연차/출장}을 신청했습니다.\n기간: {기간}"
- **구현 코드**:
  ```dart
  else {
    // 일반직원 신청 → 해당 부서 Manager + SuperAdmin 둘 다 알림
    await NotificationService.sendNotificationToAdmins(
      title: '📝 새로운 $typeLabel 신청',
      body: '$name님이 $typeLabel을 신청했습니다.\n기간: $period',
      data: {
        'type': type == 'biztrip' ? 'business_trip' : 'leave_request',
        'requester_name': name,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'leave_type': type,
        'requester_is_manager': 'false',
      },
      requesterDepartment: department,
      isManagerRequest: false,
    );
  }
  ```

## 🏢 **2. 부서별 Manager 매핑**

### **AppStrings 상수 정의**
```dart
// Manager 목록
static const List<String> managerNames = [
  '양승진', // 개발팀_manager (개발1팀, 개발2팀)
  '최창열', // 개발3팀_manager (개발3팀)
  '조근일', // 연구소_manager (연구소)
  '황연순', // 경영지원팀_manager (경영지원팀)
  '이정화', // CAD_manager (CAD)
];

// 부서별 Manager 매핑
static const Map<String, String> departmentToManager = {
  '개발1팀': '양승진',
  '개발2팀': '양승진',
  '개발3팀': '최창열',
  '연구소': '조근일',
  '경영지원팀': '황연순',
  'CAD': '이정화',
};
```

### **데이터베이스 attendance_role 매핑**

| 부서 | Manager | 이메일 | attendance_role | 관리 대상 직원 수 |
|------|---------|--------|-----------------|------------------|
| **개발1팀** | 양승진 | ysj@hansl.com | `개발팀_manager` | 3명 |
| **개발2팀** | 양승진 | ysj@hansl.com | `개발팀_manager` | 8명 |
| **개발3팀** | 최창열 | ccy@hansl.com | `개발3팀_manager` | 2명 |
| **연구소** | 조근일 | cgi@hansl.com | `연구소_manager` | 4명 |
| **경영지원팀** | 황연순 | hys@hansl.com | `경영지원팀_manager` | 2명 |
| **CAD** | 이정화 | ljh@hansl.com | `CAD_manager` | 5명 |

### **Edge Function 부서별 Manager 매핑 로직**
```typescript
const getManagerByDepartment = (department: string): string => {
  switch (department) {
    case '개발1팀':
    case '개발2팀':
      return '개발팀_manager'
    case '개발3팀':
      return '개발3팀_manager'
    case '연구소':
      return '연구소_manager'
    case '경영지원팀':
      return '경영지원팀_manager'
    case 'CAD':
      return 'CAD_manager'
    default:
      return ''
  }
}
```

## 📊 **3. 알림 시나리오별 상세 분석**

### **시나리오 A: 개발1팀 직원 (이재형) 연차 신청**
- **분류**: 일반직원 신청
- **알림 대상**: 정현웅 (SuperAdmin) + 양승진 (개발팀_manager)
- **총 알림 수**: 2명
- **제외 대상**: Admin (정영수, 정희웅)

### **시나리오 B: 개발2팀 직원 (김경태) 출장 신청**
- **분류**: 일반직원 신청
- **알림 대상**: 정현웅 (SuperAdmin) + 양승진 (개발팀_manager)
- **총 알림 수**: 2명
- **참고**: 개발1팀과 개발2팀은 동일한 Manager (양승진)

### **시나리오 C: 개발3팀 직원 (김창현) 연차 신청**
- **분류**: 일반직원 신청
- **알림 대상**: 정현웅 (SuperAdmin) + 최창열 (개발3팀_manager)
- **총 알림 수**: 2명

### **시나리오 D: 개발3팀 Manager (최창열) 출장 신청**
- **분류**: Manager 신청
- **알림 대상**: 정현웅 (SuperAdmin)만
- **총 알림 수**: 1명

### **시나리오 E: SuperAdmin (정현웅) 연차 신청**
- **분류**: SuperAdmin 신청
- **알림 대상**: 본인에게만 확인 알림
- **총 알림 수**: 1명

### **시나리오 F: CAD팀 직원 (김은정) 출장 신청**
- **분류**: 일반직원 신청
- **알림 대상**: 정현웅 (SuperAdmin) + 이정화 (CAD_manager)
- **총 알림 수**: 2명

### **시나리오 G: 연구소 직원 (박정현) 연차 신청**
- **분류**: 일반직원 신청
- **알림 대상**: 정현웅 (SuperAdmin) + 조근일 (연구소_manager)
- **총 알림 수**: 2명

### **시나리오 H: 경영지원팀 직원 (이채령) 출장 신청**
- **분류**: 일반직원 신청
- **알림 대상**: 정현웅 (SuperAdmin) + 황연순 (경영지원팀_manager)
- **총 알림 수**: 2명

## 🚫 **4. 제외 대상 및 주의사항**

### **Admin 역할 (일반직원 신청 시 제외)**
- **정영수** (jns@hansl.com) - 경영지원팀
- **정희웅** (hee-ung.jeong@hansl.com) - 경영지원팀
- **제외 이유**: 사용자 요청에 따라 일반직원 연차/출장 알림에서 제외

### **Edge Function 일반직원 알림 로직**
```typescript
// 일반직원 신청 → SuperAdmin + 해당 부서 Manager만 알림
console.log('👤 일반직원 신청이므로 SuperAdmin + 해당 부서 Manager에게 알림 전송')

// SuperAdmin FCM 토큰만 추가 (Admin 제외)
const superAdminList = allEmployees.filter((emp: any) => {
  const attendanceRole = emp.attendance_role
  if (attendanceRole && Array.isArray(attendanceRole)) {
    return attendanceRole.includes('superadmin')
  }
  return false
})
```

## ⚠️ **중요: 공통 Edge Function - 절대 삭제 금지**
- **함수**: `send_fcm_notification`
- **파일**: `supabase/functions/send_fcm_notification/index.ts`
- **용도**: **발주/구매 알림** + **연차/출장 알림** 공통 사용
- **핵심 로직**: `getAdminAndManagerTokens()` 함수에서 역할별 FCM 토큰 수집
- **⚠️ 절대 삭제 금지**: 시스템 재구성 시에도 반드시 보존해야 함

## 🔄 **5. 재설정 시 적용 가이드**

### **필수 적용 사항**
1. **3단계 분류 로직**: SuperAdmin → Manager → 일반직원
2. **부서별 Manager 매핑**: 정확한 attendance_role 사용
3. **Admin 제외**: 일반직원 신청 시 Admin 알림 제외
4. **Edge Function 로직**: `getManagerByDepartment()` 함수 정확히 구현
5. **⚠️ send_fcm_notification 보존**: 발주/구매 알림과 공통 사용하므로 절대 삭제 금지

### **변경 금지 사항**
- SuperAdmin 이메일: `hyun-woong.jeong@hansl.com`
- Manager 명단 및 부서 매핑
- 일반직원 알림에서 Admin 제외 정책

### **파일별 적용 위치**
- **Flutter**: `lib/providers/leave_provider.dart`
- **Edge Function**: `supabase/functions/send_fcm_notification/index.ts`
- **상수**: `lib/constants/app_strings.dart`

---

> **최종 업데이트**: 2025-09-18  
> **적용 범위**: 연차/출장 신청 알림 시스템 전체  
> **재설정 시**: 이 지침을 그대로 적용하여 구현
