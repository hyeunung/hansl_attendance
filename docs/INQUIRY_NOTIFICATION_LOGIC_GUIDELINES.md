# 문의하기 알림 로직 필터 지침서

> **중요**: 이 문서는 문의하기 알림 시스템의 핵심 로직과 필터를 정의합니다.  
> 파일을 새로 만들거나 시스템을 재구성할 때 이 내용을 그대로 적용하세요.

## 🎯 **1. 문의하기 알림 로직 (2단계 분류)**

### **1-1. 새 문의 생성 시** 📝
- **트리거**: `support_inquires` 테이블에 `INSERT` 발생
- **함수**: `notify_new_inquiry_to_admins()`
- **알림 대상**: **app_admin 역할을 가진 사용자**
- **알림 내용**:
  - 제목: "새로운 문의가 접수되었습니다"
  - 내용: "{사용자명}님이 {문의유형} 문의를 등록했습니다.\n제목: {문의제목}"
- **구현 방식**: SQL 트리거 → Edge Function 호출

### **1-2. 문의 상태 변경/답변 시** 💬
- **트리거**: `support_inquires` 테이블에 `UPDATE` 발생
- **함수**: `notify_inquiry_status_change()`
- **알림 대상**: **문의 작성자 개인**
- **알림 내용**:
  - 제목: "문의 답변이 도착했습니다"
  - 내용: "귀하의 문의에 대한 답변이 등록되었습니다.\n상태: {상태}"
- **구현 방식**: SQL 트리거 → Edge Function 호출

## 👥 **2. 역할별 사용자 현황**

### **app_admin 역할 (새 문의 알림 대상)**
- **정현웅** (hyun-woong.jeong@hansl.com) - 연구소
  - purchase_role: `['middle_manager', 'app_admin', 'lead buyer']`
  - FCM 토큰: ✅ 보유

### **일반 사용자 (문의 작성자)**
- **총 인원**: 29명 (전체 직원)
- **FCM 토큰 보유**: 28명
- **알림 받는 경우**: 본인이 작성한 문의에 답변이 달릴 때

## 📊 **3. 알림 시나리오별 상세 분석**

### **시나리오 A: 일반직원 (김경태) 새 문의 작성**
- **분류**: 새 문의 생성
- **알림 대상**: 정현웅 (app_admin)
- **총 알림 수**: 1명
- **트리거**: `trigger_notify_new_inquiry`

### **시나리오 B: app_admin (정현웅) 문의 답변 작성**
- **분류**: 문의 상태 변경/답변
- **알림 대상**: 문의 작성자 (김경태)
- **총 알림 수**: 1명
- **트리거**: `trigger_notify_inquiry_status_change`

### **시나리오 C: 문의 상태만 변경 (답변 없음)**
- **분류**: 문의 상태 변경
- **알림 대상**: 문의 작성자
- **총 알림 수**: 1명
- **조건**: `status` 필드 변경 시

### **시나리오 D: 답변 추가 (상태 변경 없음)**
- **분류**: 문의 답변 추가
- **알림 대상**: 문의 작성자
- **총 알림 수**: 1명
- **조건**: `resolution_note` 필드 추가/변경 시

## 🔧 **4. 기술적 구현**

### **데이터베이스 트리거**
```sql
-- 새 문의 생성 트리거
CREATE TRIGGER trigger_notify_new_inquiry
AFTER INSERT ON support_inquires
FOR EACH ROW
EXECUTE FUNCTION notify_new_inquiry_to_admins();

-- 문의 상태 변경 트리거
CREATE TRIGGER trigger_notify_inquiry_status_change
AFTER UPDATE ON support_inquires
FOR EACH ROW
EXECUTE FUNCTION notify_inquiry_status_change();
```

### **트리거 함수 로직**

#### **새 문의 알림 함수**
```sql
CREATE OR REPLACE FUNCTION notify_new_inquiry_to_admins()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_key TEXT;
BEGIN
  -- app_settings에서 필요한 값들 가져오기
  SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
  
  -- Edge Function 호출
  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send_fcm_notification',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_service_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'type', 'admin',
      'title', '새로운 문의가 접수되었습니다',
      'body', NEW.user_name || '님이 ' || NEW.inquiry_type || ' 문의를 등록했습니다.\n제목: ' || NEW.subject,
      'data', jsonb_build_object(
        'type', 'new_inquiry',
        'inquiry_id', NEW.id,
        'user_name', NEW.user_name,
        'subject', NEW.subject,
        'inquiry_type', NEW.inquiry_type
      ),
      'skip_db_notification', true
    )::jsonb
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### **문의 상태 변경 알림 함수**
```sql
CREATE OR REPLACE FUNCTION notify_inquiry_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_email TEXT;
  v_supabase_url TEXT;
  v_service_key TEXT;
BEGIN
  -- 상태가 변경되거나 답변이 추가된 경우만 처리
  IF (NEW.resolution_note IS DISTINCT FROM OLD.resolution_note AND NEW.resolution_note IS NOT NULL) 
     OR (NEW.status IS DISTINCT FROM OLD.status) THEN
    
    -- 문의자 이메일 조회
    SELECT email INTO v_user_email 
    FROM employees 
    WHERE name = NEW.user_name;
    
    -- app_settings에서 필요한 값들 가져오기
    SELECT value INTO v_supabase_url FROM app_settings WHERE key = 'supabase_url';
    SELECT value INTO v_service_key FROM app_settings WHERE key = 'supabase_service_role_key';
    
    -- Edge Function 호출
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_key,
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'type', 'user',
        'title', '문의 답변이 도착했습니다',
        'body', '귀하의 문의에 대한 답변이 등록되었습니다.\n상태: ' || NEW.status,
        'data', jsonb_build_object(
          'type', 'inquiry_response',
          'inquiry_id', NEW.id,
          'status', NEW.status,
          'resolution_note', NEW.resolution_note
        ),
        'user_email', v_user_email,
        'skip_db_notification', true
      )::jsonb
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **Frontend (Flutter) 실시간 구독**
```dart
// 실시간 구독 설정
void _setupRealtimeSubscription() {
  _realtimeSubscription = _inquiryService.subscribeToInquiryUpdates(
    onUpdate: (updatedInquiry) {
      // 업데이트된 문의 반영
      setState(() {
        final index = _inquiries.indexWhere(
          (i) => i['id'] == updatedInquiry['id'],
        );
        if (index != -1) {
          _inquiries[index] = updatedInquiry;

          // 답변이 왔을 때 알림 표시
          if (updatedInquiry['resolution_note'] != null &&
              updatedInquiry['resolution_note'].isNotEmpty) {
            _showNotification('답변이 도착했습니다!');
          }
        }
      });
    },
  );
}
```

## ⚠️ **중요: 공통 Edge Function - 절대 삭제 금지**
- **함수**: `send_fcm_notification`
- **파일**: `supabase/functions/send_fcm_notification/index.ts`
- **용도**: **발주/구매 알림** + **연차/출장 알림** + **문의하기 알림** 공통 사용
- **핵심 로직**: `getAdminAndManagerTokens()` 함수에서 역할별 FCM 토큰 수집
- **⚠️ 절대 삭제 금지**: 시스템 재구성 시에도 반드시 보존해야 함

## 🔄 **5. 재설정 시 적용 가이드**

### **필수 적용 사항**
1. **2단계 알림 로직**: 새 문의 생성 → 문의 상태 변경/답변
2. **app_admin 역할 확인**: `purchase_role`에서 `app_admin` 포함 여부 확인
3. **트리거 함수 정확 구현**: `notify_new_inquiry_to_admins()`, `notify_inquiry_status_change()`
4. **Edge Function 호출**: `send_fcm_notification` 사용
5. **⚠️ send_fcm_notification 보존**: 다른 알림 시스템과 공통 사용하므로 절대 삭제 금지

### **변경 금지 사항**
- app_admin 역할자: 정현웅 (`hyun-woong.jeong@hansl.com`)
- 트리거 테이블: `support_inquires`
- Edge Function 공통 사용 정책

### **파일별 적용 위치**
- **SQL 트리거**: `supabase/migrations/` 폴더
- **Flutter 실시간 구독**: `lib/screens/inquiry/inquiry_screen.dart`
- **Edge Function**: `supabase/functions/send_fcm_notification/index.ts` (공통 사용)

## 📋 **6. 현재 활성화된 트리거**
1. `trigger_notify_new_inquiry` (INSERT on support_inquires)
2. `trigger_notify_inquiry_status_change` (UPDATE on support_inquires)
3. `trg_support_inquiries_updated_at` (UPDATE on support_inquires) - 시간 업데이트용

---

> **최종 업데이트**: 2025-09-18  
> **적용 범위**: 문의하기 알림 시스템 전체  
> **재설정 시**: 이 지침을 그대로 적용하여 구현















