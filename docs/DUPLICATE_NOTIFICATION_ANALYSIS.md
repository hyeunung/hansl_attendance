# 연차/출장 중복 알림 문제 분석 보고서

## 🔴 문제 현황
연차/출장 신청, 취소, 승인 시 같은 푸시 알림이 **2개씩** 발송되는 문제 발생

## 🔍 중복 알림 발생 원인

### 1. 이중 저장 문제
현재 시스템에서 알림이 2번 저장되고 있습니다:

1. **DB 트리거에서 저장** (`20251001_fix_all_duplicate_notifications.sql`)
   - 트리거가 Edge Function 호출
   - 트리거 자체에서도 `notifications` 테이블에 INSERT

2. **Edge Function에서 저장** (`send_fcm_notification/index.ts`)
   - Edge Function이 FCM 발송
   - 동시에 `notifications` 테이블에 INSERT

### 2. 현재 활성화된 트리거들
- `send_leave_notification`: 연차/출장 신청 시
- `send_leave_status_change_notification`: 승인/반려 시
- 각 트리거가 중복으로 알림을 발생시킴

### 3. 문제가 있는 코드 예시

#### DB 트리거 (`20251001_fix_all_duplicate_notifications.sql`)
```sql
-- 1. Edge Function 호출 (FCM 발송 + notifications 저장)
PERFORM net.http_post(
    url := supabase_url || '/functions/v1/send_fcm_notification',
    -- ...
);

-- 2. 트리거에서도 직접 notifications 테이블에 저장 (중복!)
INSERT INTO notifications (
    type, user_email, title, body, data, is_read, created_at
) VALUES (
    -- ...
) ON CONFLICT DO NOTHING;
```

#### Edge Function (`send_fcm_notification/index.ts`)
```typescript
// 데이터베이스에 알림 저장
if (targetEmails.length > 0) {
    const notifications = targetEmails.map(email => ({
        user_email: email,
        title: title,
        body: body,
        type: data.type || type,
        data: data,
        is_read: false
    }))
    
    const { error: insertError } = await supabase
        .from('notifications')
        .insert(notifications)  // 여기서도 저장!
}
```

## ✅ 해결 방안

### 옵션 1: DB 트리거에서만 저장 (권장)
- 트리거에서 Edge Function 호출 시 `skip_db_notification: true` 파라미터 추가
- Edge Function에서는 FCM 발송만 담당
- notifications 테이블 저장은 트리거에서만 처리

### 옵션 2: Edge Function에서만 저장
- 트리거에서 notifications 테이블 INSERT 부분 제거
- Edge Function에서 FCM 발송과 DB 저장 모두 처리

### 옵션 3: 트리거 완전 비활성화
- Flutter 앱에서 직접 알림 발송하도록 변경
- 현재는 Flutter에서 알림을 보내지 않으므로 추가 개발 필요

## 📋 현재 상태 요약

| 구분 | 상태 |
|------|------|
| Flutter 앱 | 알림 발송 안 함 (DB 트리거에 의존) |
| DB 트리거 | 활성화됨 + 중복 저장 |
| Edge Function | FCM 발송 + 중복 저장 |
| 결과 | 2개의 알림 발송 |

## 🚀 즉시 적용 가능한 해결책

1. 제공된 마이그레이션 파일 실행:
   ```sql
   -- /supabase/migrations/20251001_fix_duplicate_leave_notifications_final.sql
   ```

2. Edge Function 재배포:
   ```bash
   supabase functions deploy send_fcm_notification
   ```

이 해결책은 `skip_db_notification` 파라미터를 사용하여 중복 저장을 방지합니다.
