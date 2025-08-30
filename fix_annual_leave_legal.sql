-- 법정 연차 기준에 맞춰 수정
-- 생성일: 2025-08-19T03:10:17.616Z

BEGIN;

-- 하치복: 24개 → 25개 (근속 21년 (15 + 10 = 25일))
UPDATE employees
SET annual_leave_granted_current_year = 25,
    remaining_annual_leave = 25 - COALESCE(used_annual_leave, 0)
WHERE email = 'hcb@hansl.com';

-- 김지혜: 17개 → 18개 (근속 7년 (15 + 3 = 18일))
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - COALESCE(used_annual_leave, 0)
WHERE email = 'ji-hye.kim@hansl.com';

-- 정승후: 17개 → 18개 (근속 7년 (15 + 3 = 18일))
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - COALESCE(used_annual_leave, 0)
WHERE email = 'seung-hoo.jung@hansl.com';

-- 김희승: 20개 → 18개 (근속 7년 (15 + 3 = 18일))
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - COALESCE(used_annual_leave, 0)
WHERE email = 'hee-seung.kim@hansl.com';

-- 나유성: 17개 → 18개 (근속 7년 (15 + 3 = 18일))
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - COALESCE(used_annual_leave, 0)
WHERE email = 'yu-seong.na@hansl.com';

-- 정희웅: 17개 → 18개 (근속 7년 (15 + 3 = 18일))
UPDATE employees
SET annual_leave_granted_current_year = 18,
    remaining_annual_leave = 18 - COALESCE(used_annual_leave, 0)
WHERE email = 'hee-ung.jeong@hansl.com';

-- 윤은호: 20개 → 17개 (근속 6년 (15 + 2 = 17일))
UPDATE employees
SET annual_leave_granted_current_year = 17,
    remaining_annual_leave = 17 - COALESCE(used_annual_leave, 0)
WHERE email = 'eun-ho.yoon@hansl.com';

-- 석진태: 15개 → 16개 (근속 3년 (15 + 1 = 16일))
UPDATE employees
SET annual_leave_granted_current_year = 16,
    remaining_annual_leave = 16 - COALESCE(used_annual_leave, 0)
WHERE email = 'jin-tae.seok@hansl.com';

-- 여도근: 15개 → 16개 (근속 3년 (15 + 1 = 16일))
UPDATE employees
SET annual_leave_granted_current_year = 16,
    remaining_annual_leave = 16 - COALESCE(used_annual_leave, 0)
WHERE email = 'do-geun.yeo@hansl.com';

-- 강영은: 15개 → 16개 (근속 3년 (15 + 1 = 16일))
UPDATE employees
SET annual_leave_granted_current_year = 16,
    remaining_annual_leave = 16 - COALESCE(used_annual_leave, 0)
WHERE email = 'young-eun.kang@hansl.com';

-- 이채령: 6개 → 0개 (2025년 신입 (월차 미발생))
UPDATE employees
SET annual_leave_granted_current_year = 0,
    remaining_annual_leave = 0 - COALESCE(used_annual_leave, 0)
WHERE email = 'chae-ryeong.lee@hansl.com';

-- 최창진: 5개 → 0개 (2025년 신입 (월차 미발생))
UPDATE employees
SET annual_leave_granted_current_year = 0,
    remaining_annual_leave = 0 - COALESCE(used_annual_leave, 0)
WHERE email = 'chang-jin.choi@hansl.com';

-- 박정현: 1개 → 0개 (2025년 신입 (월차 미발생))
UPDATE employees
SET annual_leave_granted_current_year = 0,
    remaining_annual_leave = 0 - COALESCE(used_annual_leave, 0)
WHERE email = 'konakona77@naver.com';

-- 최현빈: 1개 → 0개 (2025년 신입 (월차 미발생))
UPDATE employees
SET annual_leave_granted_current_year = 0,
    remaining_annual_leave = 0 - COALESCE(used_annual_leave, 0)
WHERE email = 'chlgusqls0304@gmail.com';

COMMIT;
