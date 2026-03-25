-- Phase migration skipped in local baseline.
-- business_trips table may not exist in fresh local schema after cleanup.
SELECT 'skip 2026031801_migrate_leave_biztrip_to_business_trips (table-dependent)' AS message;
