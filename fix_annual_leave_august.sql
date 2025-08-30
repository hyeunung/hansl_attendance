-- 2025년 8월 기준 연차 수정
-- 생성일: 2025-08-19T05:02:39.864Z
-- 월차: 1일 입사자는 다음달부터, 그 외는 1개월 만근 후 다음달부터

BEGIN;

-- 강영은 (2022-08-03): 15개 → 16개
-- 근속 3년 (15 + 1 = 16일)
UPDATE employees
SET annual_leave_granted_current_year = 16,
    remaining_annual_leave = 16 - 6.0
WHERE email = 'young-eun.kang@hansl.com';

-- 여도근 (2022-04-01): 15개 → 16개
-- 근속 3년 (15 + 1 = 16일)
UPDATE employees
SET annual_leave_granted_current_year = 16,
    remaining_annual_leave = 16 - 7.0
WHERE email = 'do-geun.yeo@hansl.com';

-- 석진태 (2022-03-21): 15개 → 16개
-- 근속 3년 (15 + 1 = 16일)
UPDATE employees
SET annual_leave_granted_current_year = 16,
    remaining_annual_leave = 16 - 8.0
WHERE email = 'jin-tae.seok@hansl.com';

-- 윤은호 (2019-07-01): 20개 → 17개
-- 근속 6년 (15 + 2 = 17일)
UPDATE employees
SET annual_leave_granted_current_year = 17,
    remaining_annual_leave = 17 - 11.0
WHERE email = 'eun-ho.yoon@hansl.com';

-- 나유성 (2018-09-27): 17개 → 18개
-- 근속 7년 (15 + 3 = 18일)
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - 6.5
WHERE email = 'yu-seong.na@hansl.com';

-- 정희웅 (2018-09-27): 17개 → 18개
-- 근속 7년 (15 + 3 = 18일)
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - 10.0
WHERE email = 'hee-ung.jeong@hansl.com';

-- 김희승 (2018-09-03): 20개 → 18개
-- 근속 7년 (15 + 3 = 18일)
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - 13.5
WHERE email = 'hee-seung.kim@hansl.com';

-- 정승후 (2018-07-02): 17개 → 18개
-- 근속 7년 (15 + 3 = 18일)
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - 13.5
WHERE email = 'seung-hoo.jung@hansl.com';

-- 김지혜 (2018-03-01): 17개 → 18개
-- 근속 7년 (15 + 3 = 18일)
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - 7.5
WHERE email = 'ji-hye.kim@hansl.com';

-- 하치복 (2004-03-15): 24개 → 25개
-- 근속 21년 (15 + 10 = 25일)
UPDATE employees
SET annual_leave_granted_current_year = 25,
    remaining_annual_leave = 25 - 6.5
WHERE email = 'hcb@hansl.com';

COMMIT;

-- 검증 쿼리
SELECT name, join_date, annual_leave_granted_current_year, used_annual_leave, remaining_annual_leave
FROM employees
WHERE email IN (
  'young-eun.kang@hansl.com',
  'do-geun.yeo@hansl.com',
  'jin-tae.seok@hansl.com',
  'eun-ho.yoon@hansl.com',
  'yu-seong.na@hansl.com',
  'hee-ung.jeong@hansl.com',
  'hee-seung.kim@hansl.com',
  'seung-hoo.jung@hansl.com',
  'ji-hye.kim@hansl.com',
  'hcb@hansl.com'
)
ORDER BY join_date DESC, name;
