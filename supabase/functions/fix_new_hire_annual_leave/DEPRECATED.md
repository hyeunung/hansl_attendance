# ⚠️ DEPRECATED: fix_new_hire_annual_leave Function

## 📅 Deprecated Date: 2024년 1월 (마이그레이션 완료 후)

## 🚫 Deprecation Reason
이 Edge Function은 **일회성 데이터 수정 작업**으로 **더 이상 필요하지 않습니다**.

### **이유:**
1. **마이그레이션으로 대체**: 동일한 작업이 SQL 마이그레이션으로 처리됨
   - `007_fix_new_hire_annual_leave.sql`
   - `008_correct_new_hire_calculation.sql`
2. **일회성 작업**: 과거 신입 직원 연차 수정을 위한 일회성 작업
3. **중복 방지**: 동일한 SQL 로직이 여러 곳에 중복됨

## 📋 **처리된 작업 내용**
```sql
-- 신입 직원 연차 수정 (이미 마이그레이션으로 완료)
UPDATE employees 
SET annual_leave_granted_current_year = (
  GREATEST(0, EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM join_date) + 1)
)
WHERE EXTRACT(YEAR FROM join_date) = EXTRACT(YEAR FROM CURRENT_DATE);

-- 잔여연차 재계산 (이미 마이그레이션으로 완료)  
UPDATE employees 
SET remaining_annual_leave = (
  annual_leave_granted_current_year - [사용연차]
);
```

## 🔄 **대체 솔루션**

| 기존 목적 | 현재 해결책 | 비고 |
|-----------|-------------|------|
| 신입 연차 수정 | 마이그레이션 완료 | 007, 008번 마이그레이션 |
| 향후 신입 관리 | `anniversary_check` | 입사 12개월 후 자동 처리 |
| 연차 정기 업데이트 | `annual_year_update` | 새해 전체 직원 일괄 처리 |

## 🗑️ **삭제 계획**
- **현재**: DEPRECATED 표시, 함수 유지
- **향후**: 즉시 삭제 가능 (일회성 작업 완료)

## ⚠️ **주의사항**
이 함수를 실행하면 **중복 수정**이 발생할 수 있습니다. 
이미 마이그레이션으로 처리가 완료되었으므로 실행하지 마세요.