-- Add user_email to attendance_records and backfill
ALTER TABLE public.attendance_records
ADD COLUMN IF NOT EXISTS user_email TEXT;

-- Create helpful index for lookups by email and date
CREATE INDEX IF NOT EXISTS idx_attendance_user_email_date
ON public.attendance_records (user_email, date);

-- Backfill user_email from employees table using employee_id
UPDATE public.attendance_records ar
SET user_email = e.email
FROM public.employees e
WHERE e.id = ar.employee_id
  AND ar.user_email IS NULL;


