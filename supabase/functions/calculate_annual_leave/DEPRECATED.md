# ⚠️ DEPRECATED: calculate_annual_leave Function

## 📅 Deprecated Date: 2024년 1월 (사용연차 로직 정리 시점)

## 🚫 Deprecation Reason
이 Edge Function은 **더 이상 사용되지 않습니다**.

### **이유:**
1. **프론트엔드에서 호출 안함**: 유일한 호출처였던 `_calculateAndUpdateAnnualLeave()` 함수가 삭제됨
2. **백엔드 자체 계산**: 다른 Edge Function들이 각자 연차 계산 로직을 포함
   - `anniversary_check`: 입사 기념일 시 연차 15개 지급
   - (Edge Function 없음) 년도별 연차 일괄 계산은 DB 함수 + pg_cron으로 처리
3. **중복 방지**: 연차 계산 로직 분산을 방지하고 단일 책임 원칙 적용

## 🔄 **대체 함수들**

| 기존 사용 목적 | 대체 함수 | 역할 |
|----------------|-----------|------|
| 지급연차 계산 | `anniversary_check` | 입사 기념일 연차 지급 |
| 년도별 연차 업데이트 | (DB 함수) `public.run_annual_year_update(_kst)` | 새해 전체 직원 연차 초기화 |
| 사용연차 업데이트 | `update_used_annual_leave` | 사용연차 계산 및 잔여연차 자동 계산 |

## 🗑️ **삭제 계획**
- **현재**: DEPRECATED 표시, 기능 유지
- **향후**: 6개월 후 완전 삭제 예정 (2024년 7월)

## 📝 **Migration Path**
```typescript
// ❌ OLD: 개별 연차 계산
await fetch('/functions/v1/calculate_annual_leave', {
  body: JSON.stringify({ userEmail, targetYear })
});

// ✅ NEW: 전체 직원 년도별 업데이트(관리자 SQL/크론)
// select public.run_annual_year_update(<targetYear>, <reset_usage>);

// ✅ NEW: 개별 직원 사용연차 업데이트
await fetch('/functions/v1/update_used_annual_leave', {
  body: JSON.stringify({ userEmail, targetYear })
});
```