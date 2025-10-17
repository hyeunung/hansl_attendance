-- Fix attendance statistics to show accurate leave/business trip counts for all users
-- Creates a security-definer function to bypass RLS for statistics calculation only

-- Drop function if exists
DROP FUNCTION IF EXISTS get_all_approved_leaves_for_stats();

-- Create RPC function with SECURITY DEFINER to bypass RLS for statistics
CREATE OR REPLACE FUNCTION get_all_approved_leaves_for_stats()
RETURNS TABLE(
  user_email TEXT,
  start_date DATE,
  end_date DATE,
  type TEXT
)
SECURITY DEFINER  -- 서비스키 권한으로 실행하여 RLS 우회
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Return all approved leaves for statistics calculation
  -- This ensures both managers and regular employees see the same accurate stats
  RETURN QUERY
  SELECT 
    l.user_email,
    l.start_date,
    l.end_date,
    l.type
  FROM leave l
  WHERE l.status = 'approved';
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_all_approved_leaves_for_stats() TO authenticated;

-- Add comment explaining the purpose
COMMENT ON FUNCTION get_all_approved_leaves_for_stats() IS 
'Provides approved leave data for attendance statistics calculation. Uses SECURITY DEFINER to ensure all users see consistent statistics while maintaining privacy in other contexts.';