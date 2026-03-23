import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { leaveId, type, status, startDate, endDate, reason } = await req.json();

    // 인증 헤더 확인
    const authHeader = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (!authHeader) {
      throw new Error('인증이 필요합니다');
    }

    // Supabase 클라이언트 초기화
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('환경 변수가 설정되지 않았습니다');
    }
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 사용자 인증 정보 확인
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader);
    
    if (authError || !user) {
      throw new Error('인증 실패');
    }

    // 관리자 권한 확인 및 이름 조회
    const { data: employee, error: empError } = await supabase
      .from('employees')
      .select('roles, name')
      .eq('email', user.email)
      .single();

    if (empError || !employee) {
      throw new Error('직원 정보를 찾을 수 없습니다');
    }

    // roles에서 관리자 권한 확인
    const hasAdminRole = employee.roles?.includes('admin') ||
                        employee.roles?.includes('manager') ||
                        employee.roles?.includes('superadmin');

    if (!hasAdminRole) {
      throw new Error('권한이 없습니다');
    }

    const adminName = employee.name || user.email?.split('@')[0];

    // 기존 연차 정보 조회
    const { data: oldLeave, error: fetchError } = await supabase
      .from('leave')
      .select('*')
      .eq('id', leaveId)
      .single();

    if (fetchError || !oldLeave) {
      throw new Error('연차 정보를 찾을 수 없습니다');
    }

    // 연차 정보 수정
    const { error: updateError } = await supabase
      .from('leave')
      .update({
        type,
        status,
        start_date: startDate,
        end_date: endDate,
        reason,
        updated_at: new Date().toISOString(),
      })
      .eq('id', leaveId);

    if (updateError) {
      throw new Error(`수정 실패: ${updateError.message}`);
    }


    // FCM 알림은 이제 DB 트리거(leave_update_notification)에서 자동으로 처리됨
    // Edge Function에서는 알림을 보내지 않음 (중복 방지)

    return new Response(
      JSON.stringify({
        success: true,
        message: '연차/출장이 수정되었습니다',
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    );
  } catch (error) {
    console.error('Error in update_leave:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    );
  }
});