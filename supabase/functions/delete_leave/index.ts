import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    // Service Role 키를 사용하여 RLS를 우회
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 인증 헤더 확인
    const authHeader = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (!authHeader) {
      throw new Error('인증이 필요합니다');
    }

    // 사용자 인증 정보 확인
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader);
    
    if (authError || !user) {
      throw new Error('인증 실패');
    }

    // 요청 본문 파싱
    const { leaveId, userEmail, isAdmin } = await req.json();

    if (!leaveId) {
      throw new Error('leaveId is required');
    }

    console.log('Delete request:', { leaveId, userEmail, isAdmin });

    // isAdmin이 true인 경우, 실제 권한 확인
    if (isAdmin) {
      const { data: employee, error: empError } = await supabase
        .from('employees')
        .select('attendance_role')
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
        throw new Error('관리자 권한이 없습니다');
      }
    }

    let deleteQuery = supabase
      .from('leave')
      .delete()
      .eq('id', leaveId);

    // 관리자가 아닌 경우, 본인의 pending 상태만 삭제 가능
    if (!isAdmin) {
      if (!userEmail) {
        throw new Error('userEmail is required for non-admin users');
      }
      deleteQuery = deleteQuery
        .eq('user_email', userEmail)
        .eq('status', 'pending');
    }

    // select()를 추가하여 삭제된 행을 반환
    const { data: deletedData, error } = await deleteQuery.select();

    if (error) {
      console.error('Delete error:', error);
      throw error;
    }

    if (!deletedData || deletedData.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: '삭제할 수 없는 항목이거나 이미 삭제되었습니다.' 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404 
        }
      );
    }

    console.log('Successfully deleted:', deletedData);

    // FCM 푸시 알림 전송 (관리자가 삭제한 경우만)
    if (isAdmin && deletedData && deletedData.length > 0) {
      // 관리자(삭제 수행자) 정보 조회
      const { data: adminInfo } = await supabase
        .from('employees')
        .select('name')
        .eq('email', user.email)
        .single();
      
      const adminName = adminInfo?.name || user.email?.split('@')[0] || '관리자';

      for (const leave of deletedData) {
        try {
          // 삭제된 연차의 신청자 정보 조회
          const { data: requester } = await supabase
            .from('employees')
            .select('name, fcm_token')
            .eq('email', leave.user_email)
            .single();

          if (requester?.fcm_token) {
            const typeText = {
              'annual': '연차',
              'half_am': '오전반차',
              'half_pm': '오후반차',
              'official': '공가',
              'biztrip': '출장'
            }[leave.type] || leave.type;

            const title = `${typeText} 삭제 알림`;
            const body = `${leave.start_date} ~ ${leave.end_date}\n${adminName}님이 삭제하였습니다.`;

            // FCM 푸시 알림 전송 (통일된 함수명 사용)
            await supabase.functions.invoke('send_fcm_notification', {
              body: {
                type: 'user',
                user_email: leave.user_email,
                title: title,
                body: body,
                data: {
                  type: 'leave_deleted',
                  leaveId: leave.id.toString()
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
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        deleted: deletedData,
        message: `${deletedData.length}개 항목이 삭제되었습니다.`
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    );
  }
});