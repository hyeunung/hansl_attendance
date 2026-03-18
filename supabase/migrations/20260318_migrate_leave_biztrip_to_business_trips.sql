-- ============================================================
-- Phase 1: leave 테이블의 biztrip 레코드를 business_trips로 이관
-- ============================================================
-- 주의: business_trips 테이블의 sync_business_trip_card_usage 트리거를
--       비활성화 후 작업 (이관 건에 대해 card_usages 자동 생성 방지)

-- 1. 트리거 비활성화
ALTER TABLE business_trips DISABLE TRIGGER business_trips_sync_card_usage_trigger;

-- 2. leave → business_trips 이관
INSERT INTO business_trips (
  requester_id,
  request_department,
  trip_purpose,
  trip_destination,
  trip_start_date,
  trip_end_date,
  companions,
  approval_status,
  approved_by,
  approved_at,
  created_at,
  updated_at,
  -- transport 매핑 관련 필드는 requested_vehicle_info에 저장
  precheck_note
)
SELECT
  e.id AS requester_id,
  COALESCE(e.department, '미지정') AS request_department,
  COALESCE(l.reason, '출장') AS trip_purpose,
  COALESCE(l.place, '미지정') AS trip_destination,
  l.start_date AS trip_start_date,
  l.end_date AS trip_end_date,
  -- 출장자 TEXT[] → companions JSONB 변환
  -- 본인 제외, 이름으로 employees 조인하여 [{id, name}] 형태로 변환
  COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object('id', comp_emp.id, 'name', comp_emp.name)
      )
      FROM unnest(l."출장자") AS traveler_name
      JOIN employees comp_emp ON comp_emp.name = traveler_name AND comp_emp.name != l.name
    ),
    '[]'::jsonb
  ) AS companions,
  -- status 매핑 (pending/approved/rejected 그대로)
  CASE
    WHEN l.status IN ('pending', 'approved', 'rejected') THEN l.status
    ELSE 'pending'
  END AS approval_status,
  -- approved_by: middle_manager_email → employee id
  (
    SELECT approver.id FROM employees approver
    WHERE approver.email = l.middle_manager_email
    LIMIT 1
  ) AS approved_by,
  CASE WHEN l.status = 'approved' THEN l.approved_at ELSE NULL END AS approved_at,
  l.created_at,
  COALESCE(l.updated_at, l.created_at) AS updated_at,
  -- transport 정보를 precheck_note에 보관 (참조용)
  CASE
    WHEN l.transport IS NOT NULL THEN '이관 원본 교통수단: ' || l.transport
    ELSE NULL
  END AS precheck_note
FROM leave l
JOIN employees e ON e.email = l.user_email
WHERE l.type IN ('biztrip', 'business_trip')
ORDER BY l.created_at ASC;

-- 3. 트리거 재활성화
ALTER TABLE business_trips ENABLE TRIGGER business_trips_sync_card_usage_trigger;

-- 4. 이관 완료된 leave 레코드 soft delete (type 변경)
UPDATE leave
SET type = 'biztrip_migrated',
    updated_at = now()
WHERE type IN ('biztrip', 'business_trip');

-- 5. 이관 결과 확인용 (실행 시 콘솔에서 확인)
DO $$
DECLARE
  migrated_count INTEGER;
  remaining_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO migrated_count FROM business_trips WHERE precheck_note LIKE '이관 원본%';
  SELECT COUNT(*) INTO remaining_count FROM leave WHERE type IN ('biztrip', 'business_trip');
  RAISE NOTICE '이관 완료: business_trips에 % 건 추가, leave에 biztrip 잔여 % 건', migrated_count, remaining_count;
END $$;
