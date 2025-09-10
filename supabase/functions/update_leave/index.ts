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
      .select('attendance_role, purchase_role, name')
      .eq('email', user.email)
      .single();

    if (empError || !employee) {
      throw new Error('직원 정보를 찾을 수 없습니다');
    }

    // attendance_role에서 관리자 권한 확인
    const hasAdminRole = employee.attendance_role?.includes('admin') || 
                        employee.attendance_role?.includes('manager') ||
                        employee.attendance_role?.includes('superadmin');

    if (!hasAdminRole) {
      throw new Error('권한이 없습니다');
    }

    const adminName = employee.name || user.email?.split('@')[0];
    console.log(`관리자 ${adminName}(${user.email})가 연차/출장 수정 시작: ID=${leaveId}`);

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

    console.log(`✅ 연차/출장 수정 완료: ID=${leaveId}`);

    // FCM 푸시 알림 전송 (상태가 변경된 경우)
    if (oldLeave.status !== status || oldLeave.type !== type || 
        oldLeave.start_date !== startDate || oldLeave.end_date !== endDate) {
      try {
        const { data: requester } = await supabase
          .from('employees')
          .select('name, fcm_token')
          .eq('email', oldLeave.user_email)
          .single();

        if (requester?.fcm_token) {
          const typeText = {
            'annual': '연차',
            'half_am': '오전반차',
            'half_pm': '오후반차',
            'official': '공가',
            'biztrip': '출장'
          }[type] || type;

          const statusText = {
            'approved': '승인',
            'rejected': '반려',
            'pending': '대기'
          }[status] || status;

          let title = `${typeText} 수정 알림`;
          let body = `${startDate} ~ ${endDate}\n`;
          
          if (oldLeave.status !== status) {
            const oldStatusText = {
              'approved': '승인',
              'rejected': '반려',
              'pending': '대기'
            }[oldLeave.status] || oldLeave.status;
            body += `상태: ${oldStatusText} → ${statusText}`;
          } else if (oldLeave.start_date !== startDate || oldLeave.end_date !== endDate) {
            body += `날짜가 변경되었습니다.`;
          } else {
            body += `내용이 수정되었습니다.`;
          }
          body += `\n(수정자: ${adminName})`;

          // FCM 푸시 알림 전송 (통일된 함수명 사용)
          await supabase.functions.invoke('send_fcm_notification', {
            body: {
              type: 'user',
              user_email: oldLeave.user_email,
              title: title,
              body: body,
              data: {
                type: 'leave_updated',
                leaveId: leaveId.toString(),
                status: status
              }
            }
          });

          console.log(`✅ FCM 푸시 알림 전송 완료: ${requester.name}`);
        }
      } catch (fcmError) {
        console.error('FCM 알림 전송 실패:', fcmError);
        // FCM 실패는 무시하고 계속 진행
      }
    }

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