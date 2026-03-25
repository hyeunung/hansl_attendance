-- ============================================================
-- Roles-only baseline guard
-- ============================================================
-- 목적:
-- 1) employees.roles 칼럼이 항상 존재하도록 보정
-- 2) 혹시 남아있는 레거시 권한 칼럼(attendance_role/purchase_role) 데이터는 roles로 병합
-- 3) 레거시 권한 칼럼 제거
-- 4) 구형 roles 동기화 트리거/함수 제거
--
-- 주의:
-- - 운영 DB는 이미 roles 통합 상태여도, 로컬/분기 DB 편차를 방지하기 위해 idempotent하게 작성

ALTER TABLE public.employees
ADD COLUMN IF NOT EXISTS roles TEXT[];

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'employees'
      AND column_name = 'purchase_role'
  ) OR EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'employees'
      AND column_name = 'attendance_role'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'employees'
        AND column_name = 'purchase_role'
    ) THEN
      EXECUTE $sql$
        UPDATE public.employees
        SET roles = NULLIF(
          (
            SELECT ARRAY(
              SELECT DISTINCT role_item
              FROM unnest(
                COALESCE(roles, ARRAY[]::TEXT[])
                || COALESCE(purchase_role, ARRAY[]::TEXT[])
              ) AS role_item
              ORDER BY role_item
            )
          ),
          ARRAY[]::TEXT[]
        )
      $sql$;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'employees'
        AND column_name = 'attendance_role'
    ) THEN
      EXECUTE $sql$
        UPDATE public.employees
        SET roles = NULLIF(
          (
            SELECT ARRAY(
              SELECT DISTINCT role_item
              FROM unnest(
                COALESCE(roles, ARRAY[]::TEXT[])
                || COALESCE(attendance_role, ARRAY[]::TEXT[])
              ) AS role_item
              ORDER BY role_item
            )
          ),
          ARRAY[]::TEXT[]
        )
      $sql$;
    END IF;
  END IF;
END $$;

ALTER TABLE public.employees DROP COLUMN IF EXISTS purchase_role;
ALTER TABLE public.employees DROP COLUMN IF EXISTS attendance_role;

DROP TRIGGER IF EXISTS trg_sync_roles_on_insert ON public.employees;
DROP TRIGGER IF EXISTS trg_sync_roles_to_legacy ON public.employees;

DROP FUNCTION IF EXISTS public.sync_roles_on_insert();
DROP FUNCTION IF EXISTS public.sync_roles_to_legacy();
