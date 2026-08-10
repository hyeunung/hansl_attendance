-- 석진태: 개발3팀(주 부서) 복원 + 스마트팜 겸무 처리 (2026-08-10)
-- 연차/출장 승인·통계·알림은 개발3팀(department) 기준으로 동작
UPDATE employees SET department = '개발3팀', sub_department = '스마트팜', updated_at = now()
WHERE name = '석진태' AND is_active = true;
