-- Add user_email column to attendance_records table
ALTER TABLE public.attendance_records 
ADD COLUMN IF NOT EXISTS user_email TEXT;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_attendance_records_user_email_date 
ON public.attendance_records (user_email, date);

-- Backfill user_email from employees table
UPDATE public.attendance_records ar
SET user_email = e.email
FROM public.employees e
WHERE e.id = ar.employee_id
  AND ar.user_email IS NULL;