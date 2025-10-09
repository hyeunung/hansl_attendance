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
    const { employeeId, action, clientTime } = await req.json();

    // Supabase 클라이언트 초기화
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing environment variables');
    }
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 한국 시간 기준으로 현재 시간 가져오기
    const now = new Date();
    // Deno에서는 UTC 시간을 반환하므로 KST로 변환 필요
    // toLocaleString을 사용하여 정확한 한국 시간 가져오기
    const kstTimeString = now.toLocaleString('en-US', { timeZone: 'Asia/Seoul' });
    const kstTime = new Date(kstTimeString);
    const today = kstTime.toISOString().split('T')[0];
    
    const currentHour = kstTime.getHours();
    const currentMinute = kstTime.getMinutes();
    const dayOfWeek = kstTime.getDay(); // 0 = Sunday, 6 = Saturday


    let isValid = true;
    let isLate = false;
    let message = '';

    if (action === 'clockIn') {
      // 오늘의 연차 정보 확인 (오전반차 체크)
      let hasHalfAm = false;
      
      try {
        // employeeId로 직원 이메일 조회
        const { data: employee, error: empError } = await supabase
          .from('employees')
          .select('email')
          .eq('id', employeeId)
          .single();
        
        if (employee && !empError) {
          // 오늘 승인된 오전반차가 있는지 확인
          const { data: leaves, error: leaveError } = await supabase
            .from('leave')
            .select('type')
            .eq('user_email', employee.email)
            .eq('status', 'approved')
            .eq('type', 'half_am')
            .lte('start_date', today)
            .gte('end_date', today);
          
          if (leaves && leaves.length > 0) {
            hasHalfAm = true;
          }
        }
      } catch (err) {
        console.warn('Failed to check leave status:', err);
      }

      // 출근 시간 검증
      // 평일: 00:00 ~ 23:59 (하루 종일 출근 가능)
      // 주말은 제한 없음
      if (dayOfWeek >= 1 && dayOfWeek <= 5) { // 월요일 ~ 금요일
        if (hasHalfAm) {
          // 오전반차인 경우: 13:30까지는 정상 출근
          if (currentHour > 13 || (currentHour === 13 && currentMinute > 30)) {
            isLate = true; // 13:30 이후는 지각
            message = '오전반차 출근 시간(13:30)을 초과했습니다.';
          }
        } else {
          // 일반 출근: 8:30 이후는 지각
          if (currentHour >= 9 || (currentHour === 8 && currentMinute > 30)) {
            isLate = true; // 8:30 이후는 지각
          }
        }
      }
      
    } else if (action === 'clockOut') {
      // 퇴근 시간 검증
      // 기본적으로 제한 없음 (필요시 추가 가능)
      // 예: 너무 이른 퇴근 방지
      if (currentHour < 8) {
        // 오전 8시 이전 퇴근은 경고만
        message = '이른 시간 퇴근입니다.';
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        isValid,
        isLate,
        message,
        serverTime: kstTime.toISOString(),
        clientTime,
        action,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    );
  } catch (error) {
    console.error('Error in validate_work_time:', error);
    return new Response(
      JSON.stringify({
        success: false,
        isValid: true, // 오류 시에도 일단 허용
        isLate: false,
        message: '시간 검증 서버 오류',
        error: error.message,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // 200으로 반환하여 클라이언트가 처리하도록
      },
    );
  }
});