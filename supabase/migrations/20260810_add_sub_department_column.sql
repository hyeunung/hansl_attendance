-- 겸무(병행) 부서 표시용 서브 컬럼 추가 (2026-08-10)
-- 기존 department(주 부서, 승인/통계/알림 기준)는 그대로 유지
-- sub_department는 표시/참고용이며 어떤 로직에도 사용되지 않음
ALTER TABLE employees ADD COLUMN IF NOT EXISTS sub_department TEXT;

COMMENT ON COLUMN employees.sub_department IS '겸무 부서 (표시용). 승인/통계/알림은 department 기준';

-- 김희승: 스마트팜(주) + 연구소(겸무)
UPDATE employees SET sub_department = '연구소', updated_at = now()
WHERE name = '김희승' AND is_active = true;
