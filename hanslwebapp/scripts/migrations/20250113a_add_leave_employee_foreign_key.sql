-- 20250113a_add_leave_employee_foreign_key.sql
-- Add foreign key relationship between leave.user_email and employees.email

-- 1. Add unique constraint on employees.email if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_type = 'UNIQUE' 
    AND table_name = 'employees' 
    AND constraint_name LIKE '%email%'
  ) THEN
    ALTER TABLE employees ADD CONSTRAINT unique_employees_email UNIQUE (email);
  END IF;
END $$;

-- 2. Add foreign key constraint
ALTER TABLE leave 
ADD CONSTRAINT fk_leave_user_email_employees_email 
FOREIGN KEY (user_email) 
REFERENCES employees(email)
ON DELETE CASCADE
ON UPDATE CASCADE; 