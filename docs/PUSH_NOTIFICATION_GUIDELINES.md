# 📱 HANSL 푸시 알림 시스템 완전 가이드

> ⚠️ **중요 경고**: 이 문서는 푸시 알림 시스템의 핵심 로직을 담고 있습니다. 
> **절대 수정하지 마세요!** 문제 발생 시 이 문서를 참고하여 복구하세요.

## 🚨 절대 수정 금지 항목

### ❌ 절대 건드리지 말아야 할 파일들
1. `/supabase/functions/send_fcm_notification/index.ts` - FCM 전송 핵심 로직
2. `/supabase/migrations/20251002_fix_purchase_notification_system.sql` - 구매 알림 트리거
3. `/lib/services/notification_service.dart` - Flutter 앱 알림 서비스
4. `/lib/providers/purchase_provider.dart` - 구매 알림 메시지 로직

### ⚠️ 수정 시 시스템 전체 마비 위험
- DB 트리거 삭제 또는 수정 → 자동 알림 전송 중단
- Edge Function 수정 → 모든 푸시 알림 실패
- Flutter 알림 서비스 수정 → 앱에서 알림 수신 불가

---

## 📊 전체 푸시 알림 시나리오 (11개)

### 1. 연차/출장 관련 (6개)

#### 1.1 연차 신청 알림
- **트리거**: `leave_notification` (INSERT)
- **대상**: 관리자 (admin, superadmin, 부서_manager)
- **메시지**: "🏖️ 연차 신청" / "{이름}님이 {날짜} 연차를 신청했습니다"
- **DB 트리거 코드**:
```sql
-- 파일: /supabase/migrations/20240928_add_leave_notification_trigger.sql
CREATE TRIGGER leave_notification
AFTER INSERT ON leave_requests
FOR EACH ROW 
WHEN (NEW.leave_type = '연차')
EXECUTE FUNCTION notify_manager_on_leave();
```

#### 1.2 출장 신청 알림
- **트리거**: `business_trip_notification` (INSERT)
- **대상**: 관리자
- **메시지**: "🚗 출장 신청" / "{이름}님이 {날짜} 출장을 신청했습니다"
- **DB 트리거 코드**:
```sql
CREATE TRIGGER business_trip_notification
AFTER INSERT ON leave_requests
FOR EACH ROW 
WHEN (NEW.leave_type = '출장')
EXECUTE FUNCTION notify_manager_on_leave();
```

#### 1.3 연차 승인 알림
- **트리거**: `leave_result_notification` (UPDATE - approved)
- **대상**: 신청자 본인
- **메시지**: "✅ 연차 승인" / "신청하신 연차가 승인되었습니다"
- **Flutter 코드**:
```dart
// 파일: /lib/providers/leave_provider.dart (라인 350-365)
await NotificationService.sendNotificationToUser(
  userEmail: requesterEmail,
  title: '✅ 연차 승인',
  body: '신청하신 연차가 승인되었습니다.',
  data: {
    'type': 'leave_result',
    'status': 'approved',
    'leave_type': '연차',
  },
);
```

#### 1.4 연차 반려 알림
- **트리거**: `leave_result_notification` (UPDATE - rejected)
- **대상**: 신청자 본인
- **메시지**: "❌ 연차 반려" / "신청하신 연차가 반려되었습니다. 사유: {반려사유}"

#### 1.5 출장 승인 알림
- **트리거**: `business_trip_result_notification` (UPDATE - approved)
- **대상**: 신청자 본인
- **메시지**: "✅ 출장 승인" / "신청하신 출장이 승인되었습니다"

#### 1.6 출장 반려 알림
- **트리거**: `business_trip_result_notification` (UPDATE - rejected)
- **대상**: 신청자 본인
- **메시지**: "❌ 출장 반려" / "신청하신 출장이 반려되었습니다. 사유: {반려사유}"

### 2. 구매/발주 관련 (5개)

#### 2.1 새 발주 요청 알림
- **트리거**: `purchase_request_notification` (INSERT)
- **대상**: middle_manager, app_admin
- **메시지**: "🆕 새 발주 승인 요청" / "{이름}님이 {카테고리} 발주({번호})를 요청했습니다"
- **DB 트리거 코드**:
```sql
-- 파일: /supabase/migrations/20251002_fix_purchase_notification_system.sql
CREATE TRIGGER purchase_request_notification
AFTER INSERT ON purchase_requests
FOR EACH ROW
EXECUTE FUNCTION notify_purchase_request();
```

#### 2.2 발주 1차 승인 알림
- **트리거**: `purchase_status_notification` (UPDATE - middle_manager_approved)
- **대상**: 최종 승인자 (카테고리별)
- **메시지**: "📋 최종 승인 요청" / "{이름}님의 발주가 1차 승인되어 최종 승인 대기 중입니다"
- **Flutter 코드**:
```dart
// 파일: /lib/providers/purchase_provider.dart (라인 1420-1435)
await NotificationService.sendNotificationToAdmins(
  title: '📋 최종 승인 요청',
  body: '${purchase['requester_name']}님의 발주가 1차 승인되어 최종 승인 대기 중입니다.',
  data: {
    'type': 'final_approval_request',
    'purchase_order_number': purchaseOrderNumber,
    'requester_name': purchase['requester_name'],
  },
);
```

#### 2.3 발주 최종 승인 알림
- **트리거**: `purchase_status_notification` (UPDATE - final_approved)
- **대상**: 신청자 본인
- **메시지**: "✅ 발주 승인 완료" / "{번호} 발주가 최종 승인되었습니다. 발주 진행을 해주세요."
- **중요**: "발주 진행을 해주세요" 문구 필수!
- **Flutter 코드**:
```dart
// 파일: /lib/providers/purchase_provider.dart (라인 1462-1477)
} else if (status == 'final_approved') {
  // 최종 승인 완료 -> 신청자에게 알림
  title = '✅ 발주 승인 완료';
  body = '$purchaseOrderNumber 발주가 최종 승인되었습니다. 발주 진행을 해주세요.';
  // 신청자에게 직접 알림 (targetRoles 비워둠)
}
```

#### 2.4 발주 반려 알림
- **트리거**: Manual (앱에서 직접 호출)
- **대상**: 신청자 본인
- **메시지**: "❌ 발주 반려" / "{번호} 발주가 반려되었습니다. 사유: {반려사유}"

#### 2.5 입고 완료 알림
- **트리거**: Manual (앱에서 직접 호출)
- **대상**: 요청자 및 관리자
- **메시지**: "✅ 입고 완료" / "{품목} 입고가 완료되었습니다"

---

## 🔧 핵심 구현 코드 (완전판)

### 1. DB 트리거 함수 (PostgreSQL) - 전체 코드

#### 1.1 notify_purchase_request 함수 (새 발주 요청)
```sql
-- 파일: /supabase/migrations/20251002_fix_purchase_notification_system.sql
CREATE OR REPLACE FUNCTION notify_purchase_request()
RETURNS trigger AS $$
DECLARE
  v_title TEXT;
  v_body TEXT;
  v_fcm_tokens TEXT[];
  v_requester_name TEXT;
  v_total_amount NUMERIC;
BEGIN
  -- 새 발주 요청 알림 (INSERT 시)
  IF TG_OP = 'INSERT' THEN
    v_requester_name := NEW.requester_name;
    
    -- 총 금액 계산 (옵션)
    SELECT COALESCE(SUM(amount_value), 0) INTO v_total_amount
    FROM purchase_request_items
    WHERE purchase_order_number = NEW.purchase_order_number;
    
    -- middle_manager와 app_admin의 FCM 토큰 수집
    SELECT array_agg(DISTINCT fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE ('middle_manager' = ANY(purchase_role) OR 'app_admin' = ANY(purchase_role))
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    v_title := '🆕 새 발주 승인 요청';
    v_body := format('%s님이 %s 발주(%s)를 요청했습니다. 금액: %s원',
      v_requester_name, 
      NEW.payment_category, 
      NEW.purchase_order_number,
      to_char(COALESCE(v_total_amount, 0), 'FM999,999,999')
    );
    
    -- FCM 토큰이 있는 경우에만 알림 전송
    IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
      -- Edge Function 호출
      PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
          'type', 'purchase_requests',
          'title', v_title,
          'body', v_body,
          'data', jsonb_build_object(
            'type', 'purchase_requests',
            'purchase_order_number', NEW.purchase_order_number,
            'requester_name', v_requester_name,
            'payment_category', NEW.payment_category
          ),
          'fcm_tokens', v_fcm_tokens
        )::jsonb
      );
    END IF;
    
    RAISE NOTICE '새 발주 요청 알림 전송: % (발주번호: %), FCM 토큰 수: %', 
      v_requester_name, NEW.purchase_order_number, COALESCE(array_length(v_fcm_tokens, 1), 0);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 1.2 notify_purchase_status_change 함수 (상태 변경)
```sql
-- 파일: /supabase/migrations/20251002_fix_purchase_notification_system.sql
CREATE OR REPLACE FUNCTION notify_purchase_status_change()
RETURNS trigger AS $$
DECLARE
  v_title TEXT;
  v_body TEXT;
  v_fcm_tokens TEXT[];
  v_target_email TEXT;
  v_target_roles TEXT[];
BEGIN
  -- 1차 승인 -> 최종 승인자에게 알림
  IF OLD.middle_manager_status IS DISTINCT FROM NEW.middle_manager_status 
     AND NEW.middle_manager_status = 'approved' THEN
    
    -- 카테고리별 최종 승인자 결정
    IF NEW.payment_category = '원자재' THEN
      v_target_roles := ARRAY['raw_material_manager', 'app_admin'];
    ELSIF NEW.payment_category = '소모품' THEN
      v_target_roles := ARRAY['consumable_manager', 'app_admin'];
    ELSE
      v_target_roles := ARRAY['app_admin'];
    END IF;
    
    -- 최종 승인자 FCM 토큰 수집
    SELECT array_agg(DISTINCT fcm_token) INTO v_fcm_tokens
    FROM employees
    WHERE purchase_role && v_target_roles  -- 배열 중 하나라도 일치
      AND fcm_token IS NOT NULL
      AND fcm_token != '';
    
    v_title := '📋 최종 승인 요청';
    v_body := format('%s님의 발주가 1차 승인되어 최종 승인 대기 중입니다.',
      NEW.requester_name);
    
  -- 최종 승인 -> 신청자에게 알림
  ELSIF OLD.final_manager_status IS DISTINCT FROM NEW.final_manager_status 
        AND NEW.final_manager_status = 'approved' THEN
    
    -- 신청자 이메일 찾기
    SELECT email INTO v_target_email
    FROM employees
    WHERE name = NEW.requester_name
    LIMIT 1;
    
    IF v_target_email IS NOT NULL THEN
      -- 신청자 FCM 토큰 가져오기
      SELECT ARRAY[fcm_token] INTO v_fcm_tokens
      FROM employees
      WHERE email = v_target_email
        AND fcm_token IS NOT NULL
        AND fcm_token != '';
    END IF;
    
    v_title := '✅ 발주 승인 완료';
    v_body := format('%s 발주가 최종 승인되었습니다. 발주 진행을 해주세요.',
      NEW.purchase_order_number);
    
  -- 반려 -> 신청자에게 알림
  ELSIF (OLD.middle_manager_status IS DISTINCT FROM NEW.middle_manager_status 
         AND NEW.middle_manager_status = 'rejected')
     OR (OLD.final_manager_status IS DISTINCT FROM NEW.final_manager_status 
         AND NEW.final_manager_status = 'rejected') THEN
    
    -- 신청자 이메일 찾기
    SELECT email INTO v_target_email
    FROM employees
    WHERE name = NEW.requester_name
    LIMIT 1;
    
    IF v_target_email IS NOT NULL THEN
      SELECT ARRAY[fcm_token] INTO v_fcm_tokens
      FROM employees
      WHERE email = v_target_email
        AND fcm_token IS NOT NULL
        AND fcm_token != '';
    END IF;
    
    v_title := '❌ 발주 반려';
    v_body := format('%s 발주가 반려되었습니다. 사유: %s',
      NEW.purchase_order_number,
      COALESCE(NEW.middle_manager_rejection_reason, NEW.final_manager_rejection_reason, '없음')
    );
  END IF;
  
  -- FCM 토큰이 있는 경우 알림 전송
  IF v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 THEN
    PERFORM net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'type', 'purchase_status_change',
        'title', v_title,
        'body', v_body,
        'data', jsonb_build_object(
          'type', 'purchase_status_change',
          'purchase_order_number', NEW.purchase_order_number,
          'status', CASE
            WHEN NEW.final_manager_status = 'approved' THEN 'final_approved'
            WHEN NEW.middle_manager_status = 'approved' THEN 'middle_approved'
            ELSE 'rejected'
          END
        ),
        'fcm_tokens', v_fcm_tokens
      )::jsonb
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 1.3 notify_manager_on_leave 함수 (연차/출장)
```sql
-- 파일: 여러 migration 파일에 분산
CREATE OR REPLACE FUNCTION notify_manager_on_leave()
RETURNS trigger AS $$
DECLARE
  v_requester_name TEXT;
  v_department TEXT;
  v_leave_dates TEXT;
  v_title TEXT;
  v_body TEXT;
  v_manager_tokens TEXT[];
BEGIN
  -- 신청자 정보 조회
  SELECT name, department INTO v_requester_name, v_department
  FROM employees
  WHERE email = NEW.requester_email;
  
  -- 날짜 포맷팅
  v_leave_dates := to_char(NEW.start_date, 'MM/DD') || 
                   CASE 
                     WHEN NEW.end_date != NEW.start_date 
                     THEN ' ~ ' || to_char(NEW.end_date, 'MM/DD')
                     ELSE ''
                   END;
  
  -- 알림 제목과 내용 설정
  IF NEW.leave_type = '연차' THEN
    v_title := '🏖️ 연차 신청';
    v_body := format('%s님이 %s 연차를 신청했습니다.',
      v_requester_name, v_leave_dates);
  ELSIF NEW.leave_type = '출장' THEN
    v_title := '🚗 출장 신청';
    v_body := format('%s님이 %s 출장을 신청했습니다.',
      v_requester_name, v_leave_dates);
  END IF;
  
  -- 관리자 FCM 토큰 수집 (admin, superadmin, 부서_manager)
  SELECT array_agg(DISTINCT fcm_token) INTO v_manager_tokens
  FROM employees
  WHERE (
    'admin' = ANY(attendance_role) OR
    'superadmin' = ANY(attendance_role) OR
    (v_department || '_manager') = ANY(attendance_role)
  )
  AND fcm_token IS NOT NULL
  AND fcm_token != '';
  
  -- Edge Function 호출
  IF v_manager_tokens IS NOT NULL AND array_length(v_manager_tokens, 1) > 0 THEN
    PERFORM net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/send_fcm_notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'type', 'admin',
        'title', v_title,
        'body', v_body,
        'data', jsonb_build_object(
          'type', CASE 
            WHEN NEW.leave_type = '연차' THEN 'leave_request'
            ELSE 'business_trip'
          END,
          'requester_email', NEW.requester_email,
          'requester_name', v_requester_name,
          'leave_type', NEW.leave_type,
          'start_date', NEW.start_date,
          'end_date', NEW.end_date
        ),
        'fcm_tokens', v_manager_tokens
      )::jsonb
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 2. Edge Function (TypeScript) - 전체 코드

#### 2.1 send_fcm_notification 함수 (전체)
```typescript
// 파일: /supabase/functions/send_fcm_notification/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import * as admin from "npm:firebase-admin@12.1.0";
import jwt from "npm:jsonwebtoken@9.0.2";

// Firebase Admin 초기화
const initFirebaseAdmin = () => {
  try {
    const serviceAccountKey = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountKey) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not set');
    }
    
    const serviceAccount = JSON.parse(serviceAccountKey);
    
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id
      });
    }
    return true;
  } catch (error) {
    console.error('Firebase Admin 초기화 실패:', error);
    return false;
  }
};

// Supabase 클라이언트 생성
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

serve(async (req) => {
  try {
    // Firebase Admin 초기화
    if (!initFirebaseAdmin()) {
      return new Response(
        JSON.stringify({ error: 'Firebase Admin initialization failed' }),
        { status: 500 }
      );
    }

    const { type, title, body, data, fcm_tokens, user_email, target_roles } = await req.json();

    console.log('알림 요청 받음:', { type, title, user_email, target_roles });

    let tokens: string[] = [];

    // 타입별 토큰 수집
    switch(type) {
      case 'admin':
        // 관리자 그룹 알림 (attendance_role 기반)
        if (data?.type === 'leave_request' || data?.type === 'business_trip') {
          const { data: admins } = await supabase
            .from('employees')
            .select('fcm_token')
            .or('attendance_role.cs.{admin,superadmin}')
            .not('fcm_token', 'is', null);
          
          tokens = admins?.map(a => a.fcm_token).filter(Boolean) || [];
          
          // 부서 매니저 추가
          if (data.requester_department) {
            const managerRole = `${data.requester_department}_manager`;
            const { data: managers } = await supabase
              .from('employees')
              .select('fcm_token')
              .contains('attendance_role', [managerRole])
              .not('fcm_token', 'is', null);
            
            if (managers) {
              tokens.push(...managers.map(m => m.fcm_token).filter(Boolean));
            }
          }
        } else {
          // purchase_role 기반 관리자
          const { data: admins } = await supabase
            .from('employees')
            .select('fcm_token')
            .or('purchase_role.cs.{middle_manager,app_admin}')
            .not('fcm_token', 'is', null);
          
          tokens = admins?.map(a => a.fcm_token).filter(Boolean) || [];
        }
        break;
        
      case 'user':
        // 특정 사용자 알림
        if (user_email) {
          const { data: user } = await supabase
            .from('employees')
            .select('fcm_token')
            .eq('email', user_email)
            .single();
          
          if (user?.fcm_token) {
            tokens = [user.fcm_token];
          }
        }
        break;
        
      case 'purchase_requests':
        // 구매 요청 알림 (middle_manager, app_admin)
        if (fcm_tokens) {
          tokens = fcm_tokens;
        } else {
          const { data: managers } = await supabase
            .from('employees')
            .select('fcm_token')
            .or('purchase_role.cs.{middle_manager,app_admin}')
            .not('fcm_token', 'is', null);
          
          tokens = managers?.map(m => m.fcm_token).filter(Boolean) || [];
        }
        break;
        
      case 'purchase_status_change':
        // 구매 상태 변경 알림
        if (fcm_tokens) {
          tokens = fcm_tokens;
        } else if (target_roles && target_roles.length > 0) {
          // 역할 기반 토큰 수집
          const rolesFilter = target_roles.map((role: string) => 
            `purchase_role.cs.{${role}}`
          ).join(',');
          
          const { data: targets } = await supabase
            .from('employees')
            .select('fcm_token')
            .or(rolesFilter)
            .not('fcm_token', 'is', null);
          
          tokens = targets?.map(t => t.fcm_token).filter(Boolean) || [];
        }
        break;
    }

    // 중복 제거
    tokens = [...new Set(tokens)];

    if (tokens.length === 0) {
      console.log('전송할 FCM 토큰이 없습니다');
      return new Response(
        JSON.stringify({ success: false, message: 'No FCM tokens found' }),
        { status: 200 }
      );
    }

    console.log(`${tokens.length}개의 토큰에 알림 전송 시작`);

    // FCM 메시지 구성
    const message: any = {
      notification: {
        title: title || '새 알림',
        body: body || ''
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type: data?.type || type || 'unknown',
        timestamp: new Date().toISOString()
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          priority: 'high',
          defaultVibrateTimings: true
        }
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            sound: 'default',
            badge: 1,
            alert: {
              title: title || '새 알림',
              body: body || ''
            }
          }
        },
        headers: {
          'apns-priority': '10'
        }
      }
    };

    // FCM 전송 (배치 처리)
    const batchSize = 100;
    const results = [];
    
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: batch,
          ...message
        });
        
        results.push(response);
        
        console.log(`배치 ${i / batchSize + 1} 전송 완료:`, {
          successCount: response.successCount,
          failureCount: response.failureCount
        });
        
        // 실패한 토큰 로깅
        if (response.failureCount > 0) {
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              console.error(`토큰 전송 실패 [${batch[idx]}]:`, resp.error);
            }
          });
        }
      } catch (error) {
        console.error(`배치 ${i / batchSize + 1} 전송 오류:`, error);
      }
    }

    // 전체 결과 집계
    const totalSuccess = results.reduce((sum, r) => sum + r.successCount, 0);
    const totalFailure = results.reduce((sum, r) => sum + r.failureCount, 0);

    console.log('전체 알림 전송 완료:', {
      totalSuccess,
      totalFailure,
      totalTokens: tokens.length
    });

    return new Response(
      JSON.stringify({
        success: true,
        successCount: totalSuccess,
        failureCount: totalFailure,
        totalTokens: tokens.length
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('알림 전송 중 오류:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
});
```

### 3. Flutter 앱 알림 처리 - 전체 코드

#### 3.1 NotificationService 클래스 (핵심 메서드)
```dart
// 파일: /lib/services/notification_service.dart

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static String? _fcmToken;
  
  // 중복 알림 방지를 위한 최근 전송 기록
  static final Map<String, DateTime> _recentNotifications = <String, DateTime>{};
  static const int _duplicatePreventionSeconds = 30;

  /// Firebase 알림 서비스 초기화 (라인 54-84)
  static Future<void> initialize() async {
    try {
      // 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // 로컬 알림 초기화
      await _initializeLocalNotifications();
      
      // 알림 권한 요청
      await _requestPermission();
      
      // FCM 토큰 가져오기
      await _getFCMToken();
      
      // 포그라운드 알림 설정
      await _configureForegroundNotification();
      
      // 메시지 리스너 설정
      _setupMessageListeners();
    } catch (e) {
      // 에러 처리
    }
  }

  /// FCM 토큰 가져오기 및 저장 (라인 115-202)
  static Future<void> _getFCMToken() async {
    try {
      // iOS APNS 토큰 처리 (필수)
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken().timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
        
        if (apnsToken == null && !kIsWeb) {
          // 실제 기기에서 추가 시도
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
        }
      }
      
      // FCM 토큰 가져오기
      _fcmToken = await _messaging.getToken();
      
      if (_fcmToken != null) {
        // SharedPreferences에 토큰 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        
        // 서버에 토큰 전송 (Supabase)
        await _sendTokenToServer(_fcmToken!);
      } else {
        await _retryGetToken();
      }
    } catch (e) {
      await _retryGetToken();
    }
  }

  /// Edge Function을 통한 FCM 알림 전송 (라인 716-787)
  static Future<bool> _callFCMEdgeFunction({
    required String type,
    required String title,
    required String body,
    required Map<String, String> data,
    String? requesterDepartment,
    String? userEmail,
    String? requesterEmail,
    bool isManagerRequest = false,
  }) async {
    try {
      final projectId = 'qvhbigvdfyvhoegkhvef'; // 절대 수정 금지!
      final functionUrl = 
          'https://$projectId.supabase.co/functions/v1/send_fcm_notification';
      
      final requestData = {
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        if (requesterDepartment != null) 'requester_department': requesterDepartment,
        if (userEmail != null) 'user_email': userEmail,
        if (requesterEmail != null) 'requester_email': requesterEmail,
        'is_manager_request': isManagerRequest,
      };
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 
              'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode(requestData),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 포그라운드 알림 표시 (라인 322-393)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final title = message.notification?.title ?? '새 알림';
      final body = message.notification?.body ?? '';
      final type = message.data['type'] ?? 'unknown';
      
      // iOS 배지 카운트 업데이트
      if (Platform.isIOS) {
        await _updateBadgeCount();
      }
      
      // Android 알림 채널 설정
      const androidDetails = AndroidNotificationDetails(
        'hansl_channel', // 채널 ID
        '한슬 알림', // 채널 이름
        channelDescription: '한슬 어플리케이션 알림',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      
      // iOS 알림 설정
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: null, // null로 설정하면 시스템이 자동으로 관리
      );
      
      // 플랫폼 별 설정 통합
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // 알림 ID 생성 (중복 방지)
      final notificationId = 
          message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
      
      // 로컬 알림 표시
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      // 에러 처리
    }
  }

  /// 알림 탭 처리 (라인 416-661)
  static void _handleNotificationTap(RemoteMessage message) async {
    try {
      String? type = message.data['type'];
      final context = navigatorKey.currentContext;
      
      if (context == null) return;
      
      switch (type) {
        case 'leave_request':
        case 'business_trip':
          // 연차/출장 신청 알림 - 관리자는 승인 탭으로 이동
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final response = await Supabase.instance.client
                .from('employees')
                .select('attendance_role')
                .eq('email', user.email!)
                .single();
            
            final List<dynamic> attendanceRoles = 
                (response['attendance_role'] as List<dynamic>?) ?? [];
            
            final approvalRoles = ['admin', 'superadmin', '개발3팀_manager', 
                                  'CAD_manager', '개발팀_manager', 
                                  '경영지원팀_manager', '연구소_manager'];
            
            final hasApprovalRole = attendanceRoles.any((role) => 
                approvalRoles.contains(role));
            
            if (hasApprovalRole) {
              // 관리자는 승인 탭(index 2)으로 이동 - 연차/출장 탭(0)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MainTab(
                    initialIndex: 2,  // 승인 탭
                    approvalSubTab: 0, // 연차/출장 서브탭
                  ),
                ),
                (route) => false,
              );
            } else {
              // 일반 사용자는 홈 탭으로 이동
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MainTab(initialIndex: 0),
                ),
                (route) => false,
              );
            }
          }
          break;
          
        case 'purchase_requests':
        case 'final_approval_request':
        case 'purchase_approval':
          // 발주 관련 알림 - 권한에 따라 이동
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final response = await Supabase.instance.client
                .from('employees')
                .select('purchase_role')
                .eq('email', user.email!)
                .single();
            
            final List<dynamic> purchaseRoles = 
                (response['purchase_role'] as List<dynamic>?) ?? [];
            
            final approvalRoles = ['middle_manager', 'raw_material_manager', 
                                  'consumable_manager', 'app_admin'];
            
            final hasApprovalRole = purchaseRoles.any((role) => 
                approvalRoles.contains(role));
            
            if (hasApprovalRole) {
              // 발주 승인 권한자는 승인관리 탭(index 2) - 발주승인 탭(1)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MainTab(
                    initialIndex: 2,  // 승인관리 탭
                    approvalSubTab: 1, // 발주승인 서브탭
                  ),
                ),
                (route) => false,
              );
            } else {
              // 일반 사용자는 홈 탭으로 이동
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MainTab(initialIndex: 0),
                ),
                (route) => false,
              );
            }
          }
          break;
          
        default:
          // 기본 홈 화면으로 이동
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => MainTab(initialIndex: 0),
            ),
            (route) => false,
          );
      }
    } catch (e) {
      // 에러 처리
    }
  }

  /// 중복 알림 방지 체크 (라인 790-826)
  static bool _isDuplicateNotification(
    String userEmail,
    String title, 
    String type,
  ) {
    final key = '${userEmail}_${title}_$type';
    final now = DateTime.now();
    
    if (_recentNotifications.containsKey(key)) {
      final lastSent = _recentNotifications[key]!;
      final secondsElapsed = now.difference(lastSent).inSeconds;
      
      if (secondsElapsed < _duplicatePreventionSeconds) {
        return true;
      }
    }
    
    // 기록 저장 및 5분 이상 된 기록 정리
    _recentNotifications[key] = now;
    _recentNotifications.removeWhere(
      (key, timestamp) => now.difference(timestamp).inMinutes > 5,
    );
    
    return false;
  }

  /// Admin + 부서별 관리자에게 알림 전송 (라인 829-883)
  static Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    required Map<String, String> data,
    String? requesterDepartment,
    String? requesterEmail,
    bool isManagerRequest = false,
  }) async {
    try {
      // 중복 알림 방지 체크
      final notificationType = data['type'] ?? 'admin';
      if (_isDuplicateNotification(
        requesterEmail ?? 'admin',
        title,
        notificationType,
      )) {
        return;
      }
      
      await _callFCMEdgeFunction(
        type: 'admin',
        title: title,
        body: body,
        data: data,
        requesterDepartment: requesterDepartment,
        requesterEmail: requesterEmail,
        isManagerRequest: isManagerRequest,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 특정 사용자에게 푸시 알림 전송 (라인 886-925)
  static Future<void> sendNotificationToUser({
    required String userEmail,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // 중복 알림 방지 체크
      final notificationType = data['type'] ?? 'user';
      if (_isDuplicateNotification(userEmail, title, notificationType)) {
        return;
      }
      
      await _callFCMEdgeFunction(
        type: 'user',
        title: title,
        body: body,
        data: data,
        userEmail: userEmail,
      );
    } catch (e) {
      rethrow;
    }
  }
}
```

#### 3.2 PurchaseProvider 알림 전송 로직
```dart
// 파일: /lib/providers/purchase_provider.dart

class PurchaseProvider extends ChangeNotifier {
  
  /// 발주 상태 변경 알림 전송 (라인 1400-1500)
  Future<void> _sendPurchaseApprovalNotification({
    required String status,
    required bool isMiddleManager,
    String? rejectionReason,
  }) async {
    try {
      final purchase = selectedPurchase;
      if (purchase == null) return;
      
      final purchaseOrderNumber = purchase['purchase_order_number'] ?? '';
      String title = '';
      String body = '';
      List<String> targetRoles = [];
      
      if (isMiddleManager) {
        if (status == 'approved') {
          // 1차 승인 완료 -> 최종 승인자에게 알림
          title = '📋 최종 승인 요청';
          body = '${purchase['requester_name']}님의 발주가 1차 승인되어 최종 승인 대기 중입니다.';
          
          // 카테고리별 최종 승인자 결정
          final category = purchase['payment_category'] ?? '';
          if (category == '원자재') {
            targetRoles = ['raw_material_manager'];
          } else if (category == '소모품') {
            targetRoles = ['consumable_manager'];
          }
          targetRoles.add('app_admin'); // app_admin은 항상 포함
          
          // 최종 승인자에게 알림 전송
          await NotificationService.sendNotificationToAdmins(
            title: title,
            body: body,
            data: {
              'type': 'final_approval_request',
              'purchase_order_number': purchaseOrderNumber,
              'requester_name': purchase['requester_name'],
              'payment_category': category,
            },
            requesterEmail: purchase['requester_email'],
          );
        } else if (status == 'rejected') {
          // 1차 반려 -> 신청자에게 알림
          title = '❌ 발주 반려';
          body = '$purchaseOrderNumber 발주가 1차 승인에서 반려되었습니다.';
          if (rejectionReason != null && rejectionReason.isNotEmpty) {
            body += '\n반려 사유: $rejectionReason';
          }
        }
      } else if (status == 'final_approved') {
        // 최종 승인 완료 -> 신청자에게 알림
        title = '✅ 발주 승인 완료';
        body = '$purchaseOrderNumber 발주가 최종 승인되었습니다. 발주 진행을 해주세요.';
        // 신청자에게 직접 알림 (targetRoles 비워둠)
      } else if (status == 'final_rejected') {
        // 최종 반려 -> 신청자에게 알림
        title = '❌ 발주 반려';
        body = '$purchaseOrderNumber 발주가 최종 승인에서 반려되었습니다.';
        if (rejectionReason != null && rejectionReason.isNotEmpty) {
          body += '\n반려 사유: $rejectionReason';
        }
      }
      
      // 신청자에게 알림 전송 (반려 또는 최종 승인)
      if (status.contains('rejected') || status == 'final_approved') {
        // 신청자 이메일 찾기
        final requesterName = purchase['requester_name'];
        if (requesterName != null) {
          try {
            final response = await _supabase
                .from('employees')
                .select('email')
                .eq('name', requesterName)
                .single();
            
            final requesterEmail = response['email'] as String?;
            
            if (requesterEmail != null) {
              await NotificationService.sendNotificationToUser(
                userEmail: requesterEmail,
                title: title,
                body: body,
                data: {
                  'type': status == 'final_approved' ? 'purchase_approved' : 'purchase_rejected',
                  'purchase_order_number': purchaseOrderNumber,
                  'status': status,
                },
              );
            }
          } catch (e) {
            // 신청자 이메일을 찾지 못한 경우 무시
          }
        }
      }
    } catch (e) {
      // 알림 전송 실패해도 프로세스는 계속
    }
  }
}
```

---

## 🔀 푸시 알림 전체 흐름도 (상세 경로)

### 📌 구매/발주 알림 흐름

#### 1️⃣ 새 발주 요청 생성 시
```
[사용자 액션]
Flutter 앱에서 발주 요청 생성
↓
[DB 삽입]
purchase_requests 테이블에 INSERT
↓
[트리거 발동]
purchase_request_notification 트리거 (AFTER INSERT)
↓
[함수 실행]
notify_purchase_request() PostgreSQL 함수
↓
[FCM 토큰 수집]
SELECT fcm_token FROM employees 
WHERE 'middle_manager' = ANY(purchase_role) 
   OR 'app_admin' = ANY(purchase_role)
↓
[Edge Function 호출]
net.http_post() → /functions/v1/send_fcm_notification
↓
[Edge Function 처리]
type: 'purchase_requests' 라우팅
↓
[Firebase FCM 전송]
admin.messaging().sendEachForMulticast()
↓
[푸시 알림 수신]
middle_manager, app_admin 휴대폰에 알림
```

#### 2️⃣ 발주 1차 승인 시
```
[사용자 액션]
Flutter 앱에서 middle_manager가 승인
↓
[DB 업데이트]
UPDATE purchase_requests 
SET middle_manager_status = 'approved'
↓
[트리거 발동]
purchase_status_notification 트리거 (AFTER UPDATE)
↓
[함수 실행]
notify_purchase_status_change() PostgreSQL 함수
↓
[조건 체크]
IF OLD.middle_manager_status != NEW.middle_manager_status 
   AND NEW.middle_manager_status = 'approved'
↓
[최종 승인자 결정]
IF payment_category = '원자재' → raw_material_manager + app_admin
IF payment_category = '소모품' → consumable_manager + app_admin
ELSE → app_admin만
↓
[FCM 토큰 수집]
SELECT fcm_token FROM employees 
WHERE purchase_role && ARRAY['결정된_역할들']
↓
[Edge Function 호출]
net.http_post() → /functions/v1/send_fcm_notification
↓
[푸시 알림 수신]
최종 승인자들 휴대폰에 알림
```

#### 3️⃣ 최종 승인 시 (중요!)
```
[사용자 액션]
Flutter 앱에서 최종 승인자가 승인
↓
[DB 업데이트]
UPDATE purchase_requests 
SET final_manager_status = 'approved'
↓
[트리거 발동]
purchase_status_notification 트리거
↓
[함수 실행]
notify_purchase_status_change()
↓
[조건 체크]
ELSIF OLD.final_manager_status != NEW.final_manager_status 
      AND NEW.final_manager_status = 'approved'
↓
[신청자 찾기]
SELECT email FROM employees 
WHERE name = NEW.requester_name
↓
[FCM 토큰 가져오기]
SELECT ARRAY[fcm_token] FROM employees 
WHERE email = '신청자_이메일'
↓
[메시지 생성]
title = '✅ 발주 승인 완료'
body = 'XXX 발주가 최종 승인되었습니다. 발주 진행을 해주세요.'
↓
[Edge Function 호출]
type: 'purchase_status_change'
↓
[푸시 알림 수신]
신청자 휴대폰에 "발주 진행을 해주세요" 메시지 포함 알림
```

### 📌 연차/출장 알림 흐름

#### 1️⃣ 연차 신청 시
```
[사용자 액션]
Flutter 앱에서 연차 신청
↓
[DB 삽입]
INSERT INTO leave_requests (leave_type = '연차', ...)
↓
[트리거 발동]
leave_notification 트리거 (AFTER INSERT WHEN leave_type = '연차')
↓
[함수 실행]
notify_manager_on_leave() PostgreSQL 함수
↓
[신청자 정보 조회]
SELECT name, department FROM employees 
WHERE email = NEW.requester_email
↓
[관리자 FCM 토큰 수집]
SELECT fcm_token FROM employees 
WHERE 'admin' = ANY(attendance_role) 
   OR 'superadmin' = ANY(attendance_role)
   OR (department || '_manager') = ANY(attendance_role)
↓
[메시지 생성]
title = '🏖️ 연차 신청'
body = 'XXX님이 MM/DD 연차를 신청했습니다.'
↓
[Edge Function 호출]
type: 'admin', data.type: 'leave_request'
↓
[푸시 알림 수신]
관리자들 휴대폰에 알림
```

#### 2️⃣ 연차 승인/반려 시 (Flutter 앱에서 직접)
```
[사용자 액션]
관리자가 Flutter 앱에서 승인/반려
↓
[Flutter Provider]
LeaveProvider.approveLeave() 또는 rejectLeave()
↓
[DB 업데이트]
UPDATE leave_requests SET status = 'approved/rejected'
↓
[Flutter에서 직접 알림 호출]
NotificationService.sendNotificationToUser(
  userEmail: requesterEmail,
  title: '✅ 연차 승인' 또는 '❌ 연차 반려',
  body: '신청하신 연차가 승인/반려되었습니다.'
)
↓
[Edge Function 호출]
_callFCMEdgeFunction(type: 'user', ...)
↓
[Edge Function 처리]
type: 'user' → 특정 사용자 FCM 토큰 조회
↓
[푸시 알림 수신]
신청자 휴대폰에 결과 알림
```

### 📌 Edge Function 내부 라우팅 상세

```typescript
// /supabase/functions/send_fcm_notification/index.ts

switch(type) {
  case 'admin':
    // 관리자 그룹 알림
    if (data?.type === 'leave_request' || data?.type === 'business_trip') {
      // attendance_role 기반 (연차/출장)
      → employees 테이블에서 attendance_role 확인
      → admin, superadmin, 부서_manager FCM 토큰 수집
    } else {
      // purchase_role 기반 (발주)
      → employees 테이블에서 purchase_role 확인
      → middle_manager, app_admin FCM 토큰 수집
    }
    break;
    
  case 'user':
    // 특정 사용자 알림
    → user_email 파라미터로 받은 이메일
    → employees 테이블에서 해당 사용자 FCM 토큰 조회
    → 단일 사용자에게만 전송
    break;
    
  case 'purchase_requests':
    // 새 발주 요청 (DB 트리거에서 호출)
    → fcm_tokens 파라미터로 받은 토큰 사용
    → 또는 middle_manager, app_admin 토큰 자동 수집
    break;
    
  case 'purchase_status_change':
    // 발주 상태 변경 (DB 트리거에서 호출)
    → fcm_tokens 파라미터로 받은 토큰 사용
    → 또는 target_roles 기반 토큰 수집
    break;
}
```

### 📌 DB 트리거 목록 및 위치

| 트리거명 | 테이블 | 이벤트 | 조건 | 함수 | 용도 |
|---------|--------|--------|------|------|------|
| purchase_request_notification | purchase_requests | AFTER INSERT | - | notify_purchase_request() | 새 발주 요청 |
| purchase_status_notification | purchase_requests | AFTER UPDATE | 상태 변경 시 | notify_purchase_status_change() | 발주 승인/반려 |
| leave_notification | leave_requests | AFTER INSERT | leave_type = '연차' | notify_manager_on_leave() | 연차 신청 |
| business_trip_notification | leave_requests | AFTER INSERT | leave_type = '출장' | notify_manager_on_leave() | 출장 신청 |
| leave_result_notification | leave_requests | AFTER UPDATE | status 변경 | notify_leave_result() | 연차 결과 |
| business_trip_result_notification | leave_requests | AFTER UPDATE | status 변경 | notify_leave_result() | 출장 결과 |

### 📌 Firebase FCM 전송 과정

```
1. Edge Function이 FCM 메시지 구성
   {
     notification: { title, body },
     data: { type, timestamp, ... },
     android: { priority: 'high' },
     apns: { aps: { badge: 1, sound: 'default' } }
   }

2. Firebase Admin SDK 호출
   admin.messaging().sendEachForMulticast({
     tokens: [...FCM토큰들...],
     ...message
   })

3. Firebase 서버가 각 플랫폼으로 전송
   - Android: FCM 서버 → Google Play Services → 앱
   - iOS: FCM 서버 → APNs → 앱

4. Flutter 앱에서 수신
   - 포그라운드: FirebaseMessaging.onMessage → _showLocalNotification()
   - 백그라운드: _firebaseMessagingBackgroundHandler()
   - 종료 상태: 시스템이 알림 표시, 탭 시 앱 실행
```

### 📌 중요 환경변수 및 설정

```bash
# Supabase Edge Function 환경변수
FIREBASE_SERVICE_ACCOUNT_JSON  # Firebase 서비스 계정 키 (JSON)
SUPABASE_URL                   # Supabase 프로젝트 URL
SUPABASE_SERVICE_ROLE_KEY      # Supabase 서비스 역할 키

# PostgreSQL 설정 (app_settings 테이블)
app.supabase_url               # current_setting('app.supabase_url')
app.service_role_key           # current_setting('app.service_role_key')

# Flutter 앱 상수
projectId = 'qvhbigvdfyvhoegkhvef'  # Supabase 프로젝트 ID (절대 변경 금지!)
```

---

## 🔄 복구 절차

### 1. 푸시 알림이 전혀 오지 않는 경우

#### 1단계: Firebase 서비스 계정 키 확인
```bash
# 키 유효성 확인
node check_service_account_validity.js

# 키 재설정 (필요시)
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat hansl-attendance-firebase-adminsdk.json)" --project-ref qvhbigvdfyvhoegkhvef
```

#### 2단계: DB 트리거 확인
```sql
-- 트리거 목록 확인
SELECT * FROM pg_trigger WHERE tgname LIKE '%notification%';

-- 트리거 재생성 (필요시)
-- /supabase/migrations/20251002_fix_purchase_notification_system.sql 실행
```

#### 3단계: Edge Function 확인
```bash
# Edge Function 로그 확인
npx supabase functions logs send_fcm_notification --project-ref qvhbigvdfyvhoegkhvef

# Edge Function 재배포 (필요시)
npx supabase functions deploy send_fcm_notification --project-ref qvhbigvdfyvhoegkhvef
```

### 2. 특정 알림만 오지 않는 경우

#### 연차/출장 알림 복구
```sql
-- 트리거 재생성
DROP TRIGGER IF EXISTS leave_notification ON leave_requests;
CREATE TRIGGER leave_notification
AFTER INSERT ON leave_requests
FOR EACH ROW 
WHEN (NEW.leave_type = '연차')
EXECUTE FUNCTION notify_manager_on_leave();
```

#### 구매/발주 알림 복구
```sql
-- 트리거 재생성
DROP TRIGGER IF EXISTS purchase_request_notification ON purchase_requests;
CREATE TRIGGER purchase_request_notification
AFTER INSERT ON purchase_requests
FOR EACH ROW
EXECUTE FUNCTION notify_purchase_request();

DROP TRIGGER IF EXISTS purchase_status_notification ON purchase_requests;
CREATE TRIGGER purchase_status_notification
AFTER UPDATE ON purchase_requests
FOR EACH ROW
WHEN (OLD.middle_manager_status IS DISTINCT FROM NEW.middle_manager_status
   OR OLD.final_manager_status IS DISTINCT FROM NEW.final_manager_status)
EXECUTE FUNCTION notify_purchase_status_change();
```

### 3. 알림 메시지 수정이 필요한 경우

⚠️ **주의**: 메시지 텍스트만 수정하고, 로직은 절대 변경하지 마세요!

#### 최종 승인 메시지 예시
```dart
// 파일: /lib/providers/purchase_provider.dart
// ✅ 올바른 수정 (텍스트만 변경)
body = '$purchaseOrderNumber 발주가 최종 승인되었습니다. 발주 진행을 해주세요.';

// ❌ 잘못된 수정 (로직 변경)
if (someCondition) {  // 조건 추가 금지!
  body = '...';
}
```

---

## 📋 테스트 절차

### 1. 전체 푸시 알림 테스트
```bash
# 테스트 스크립트 실행
./test_all_push_notifications_with_db.sh

# 테스트 계정: test@hansl.com
# 확인 항목:
# - 연차 신청 → 관리자 알림
# - 연차 승인 → 신청자 알림  
# - 발주 요청 → middle_manager 알림
# - 1차 승인 → 최종 승인자 알림
# - 최종 승인 → 신청자 알림 (발주 진행 문구 확인!)
```

### 2. 개별 알림 테스트

#### 구매 요청 테스트
```sql
-- test@hansl.com 계정으로 테스트 데이터 삽입
INSERT INTO purchase_requests (
  purchase_order_number,
  requester_name,
  payment_category,
  vendor_id,
  request_type
) VALUES (
  'TEST-' || to_char(now(), 'YYYYMMDDHH24MISS'),
  'test',
  '발주',
  204,
  '소모품'
);
```

#### 최종 승인 테스트
```sql
-- 최종 승인 상태로 변경
UPDATE purchase_requests 
SET final_manager_status = 'approved',
    final_manager_approved_at = now()
WHERE purchase_order_number = 'TEST-XXX';
```

---

## ⚠️ 주의사항 및 금지사항

### 절대 하지 말아야 할 것들

1. **DB 트리거 삭제 금지**
   ```sql
   -- ❌ 절대 실행 금지!
   DROP TRIGGER purchase_request_notification ON purchase_requests;
   ```

2. **Edge Function URL 변경 금지**
   ```dart
   // ❌ 프로젝트 ID 변경 금지!
   final projectId = 'qvhbigvdfyvhoegkhvef'; // 절대 수정 금지!
   ```

3. **FCM 토큰 수집 로직 변경 금지**
   ```sql
   -- ❌ 권한 조건 변경 금지!
   WHERE ('middle_manager' = ANY(purchase_role) OR 'app_admin' = ANY(purchase_role))
   ```

4. **알림 타입 변경 금지**
   ```dart
   // ❌ type 값 변경 금지!
   data: {
     'type': 'purchase_requests', // 절대 변경 금지!
   }
   ```

### 안전한 수정 방법

1. **메시지 텍스트만 수정**
2. **새로운 알림 추가시 기존 로직 복사**
3. **테스트 환경에서 먼저 확인**
4. **변경 전 백업 필수**

---

## 📞 문제 발생시 연락처

- **개발팀**: 기존 푸시 알림 로직 문의
- **Firebase Console**: 서비스 계정 키 재생성
- **Supabase Dashboard**: Edge Function 로그 확인

---

## 📝 변경 이력

- **2025.10.11**: 최종 승인 메시지에 "발주 진행을 해주세요" 추가
- **2025.10.11**: 출퇴근 알림, 기타 알림 제거
- **2025.10.11**: 전체 푸시 알림 시스템 문서화 완료

---

## 🔒 보안 주의사항

- Firebase 서비스 계정 키는 절대 외부에 노출하지 마세요
- Supabase Service Role Key는 서버 사이드에서만 사용하세요
- FCM 토큰은 개인정보이므로 로그에 남기지 마세요

---

**마지막 업데이트**: 2025년 10월 11일
**작성자**: HANSL 개발팀
**문서 버전**: 1.0.0