const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function createNotificationsTable() {
  try {
    console.log('📋 Checking if notifications table exists...');
    
    // Check if table exists
    const { data: tables, error: checkError } = await supabase
      .from('notifications')
      .select('*')
      .limit(1);
    
    if (!checkError) {
      console.log('✅ notifications table already exists');
      return;
    }
    
    if (checkError.code === '42P01') { // Table doesn't exist
      console.log('⚠️ notifications table not found, creating it now...');
      
      // Since we can't run DDL directly through Supabase client,
      // we'll need to use the dashboard or SQL editor
      console.log('\n🔧 Please run the following SQL in Supabase Dashboard SQL Editor:\n');
      
      const sql = `
-- 알림 테이블 생성
CREATE TABLE IF NOT EXISTS public.notifications (
    id SERIAL PRIMARY KEY,
    user_email TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_notifications_user_email ON public.notifications(user_email);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- RLS 정책
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 알림만 조회 가능
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT
    USING (auth.jwt() ->> 'email' = user_email);

-- 사용자는 자신의 알림 읽음 상태만 업데이트 가능
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE
    USING (auth.jwt() ->> 'email' = user_email);

-- 서비스 역할은 모든 알림 생성 가능
CREATE POLICY "Service role can insert notifications" ON public.notifications
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- 사용자는 자신의 알림만 삭제 가능
CREATE POLICY "Users can delete own notifications" ON public.notifications
    FOR DELETE
    USING (auth.jwt() ->> 'email' = user_email);
`;
      
      console.log(sql);
      console.log('\n📝 Copy and paste the above SQL into Supabase Dashboard > SQL Editor');
      console.log('🔗 URL: ' + supabaseUrl.replace('/rest/v1', '') + '/project/default/editor');
    } else {
      console.error('❌ Unexpected error:', checkError.message);
    }
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

createNotificationsTable();