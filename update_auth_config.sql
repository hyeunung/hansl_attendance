-- Update Supabase Auth configuration for mobile deep links

-- Update site_url to the mobile app deep link
UPDATE auth.config 
SET site_url = 'com.hansl.app://auth-callback'
WHERE parameter = 'site_url';

-- Insert or update redirect URLs to include mobile deep link
INSERT INTO auth.config (parameter, value) 
VALUES ('additional_redirect_urls', '["com.hansl.app://auth-callback", "https://hansl-webapp.vercel.app", "http://localhost:3000"]')
ON CONFLICT (parameter) 
DO UPDATE SET value = EXCLUDED.value;

-- Verify the changes
SELECT parameter, value FROM auth.config WHERE parameter IN ('site_url', 'additional_redirect_urls');