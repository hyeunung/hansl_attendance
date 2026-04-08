-- Fix: get_all_approved_leaves_for_stats에 business_trips 테이블 포함
-- 출장자가 미출근으로 잘못 표시되는 버그 수정

DROP FUNCTION IF EXISTS get_all_approved_leaves_for_stats();

CREATE OR REPLACE FUNCTION get_all_approved_leaves_for_stats()
RETURNS TABLE(
  user_email TEXT,
  start_date DATE,
  end_date DATE,
  type TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  -- leave 테이블 (연차, 반차, 공가 등)
  SELECT
    l.user_email,
    l.start_date,
    l.end_date,
    l.type
  FROM leave l
  WHERE l.status = 'approved'
    AND l.type != 'biztrip_migrated'

  UNION ALL

  -- business_trips 테이블 (출장)
  SELECT
    e.email AS user_email,
    bt.trip_start_date AS start_date,
    bt.trip_end_date AS end_date,
    'biztrip'::TEXT AS type
  FROM business_trips bt
  JOIN employees e ON e.id = bt.requester_id
  WHERE bt.approval_status IN ('approved', 'completed');
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_approved_leaves_for_stats() TO authenticated;

COMMENT ON FUNCTION get_all_approved_leaves_for_stats() IS
'Provides approved leave + business trip data for attendance statistics. Includes business_trips table via UNION.';
