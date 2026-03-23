import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface AnniversaryCheckRequest {
  targetDate?: string; // YYYY-MM-DD 형식
  force?: boolean; // 강제 실행 옵션
}

interface Employee {
  id: number;
  email: string;
  name: string;
  join_date: string;
  annual_leave_granted_current_year: number;
  remaining_annual_leave: number;
}

interface AnniversaryResult {
  employeeId: number;
  employeeName: string;
  joinDate: string;
  anniversaryDate: string;
  previousLeave: number;
  newLeave: number;
  usedLeave: number;
  newRemainingLeave: number;
  message: string;
}

Deno.serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 🔒 관리자 인증 확인 (입사 기념일 체크는 관리자만 가능)
    const authHeader = req.headers.get('authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: '인증 토큰이 필요합니다.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 사용자 토큰 검증
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
    if (authError || !user || !user.email) {
      return new Response(
        JSON.stringify({ success: false, error: '유효하지 않은 인증 토큰입니다.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 관리자 권한 확인
    const { data: currentEmployee, error: empError } = await supabase
      .from('employees')
      .select('email, roles')
      .eq('email', user.email)
      .single();

    if (empError || !currentEmployee) {
      return new Response(
        JSON.stringify({ success: false, error: '직원 정보를 찾을 수 없습니다.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const isAdmin = currentEmployee.roles && 
                   Array.isArray(currentEmployee.roles) && 
                   currentEmployee.roles.includes('admin');

    if (!isAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: '입사 기념일 체크는 관리자만 실행할 수 있습니다.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Parse request body
    const requestBody = req.method === 'POST' ? await req.json() : {};
    const { targetDate, force = false }: AnniversaryCheckRequest = requestBody;

    // 한국 시간 기준 날짜 계산
    const now = new Date();
    const kstOffset = 9 * 60 * 60 * 1000; // UTC+9
    const kstDate = new Date(now.getTime() + kstOffset);
    
    const checkDate = targetDate ? new Date(targetDate) : kstDate;
    const checkDateStr = checkDate.toISOString().split('T')[0]; // YYYY-MM-DD


    // 정확히 1년 전 오늘 입사한 직원들 찾기
    const oneYearAgo = new Date(checkDate);
    oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
    const targetJoinDate = oneYearAgo.toISOString().split('T')[0];

    const { data: anniversaryEmployees, error: employeeError } = await supabase
      .from('employees')
      .select('id, email, name, join_date, annual_leave_granted_current_year, remaining_annual_leave')
      .eq('join_date', targetJoinDate);

    if (employeeError) {
      throw new Error(`입사 기념일 직원 조회 실패: ${employeeError.message}`);
    }

    if (!anniversaryEmployees || anniversaryEmployees.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: `${checkDateStr}에 입사 12개월 완성인 직원이 없습니다.`,
          results: []
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }


    const results: AnniversaryResult[] = [];

    // 각 직원별로 연차 업데이트
    for (const employee of anniversaryEmployees) {
      const result = await processAnniversary(supabase, employee, checkDateStr);
      results.push(result);
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `${checkDateStr} 입사 기념일 체크 완료`,
        results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('입사 기념일 체크 중 오류:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : '알 수 없는 오류' 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function processAnniversary(
  supabase: any,
  employee: Employee,
  anniversaryDate: string
): Promise<AnniversaryResult> {
  try {
    const previousLeave = employee.annual_leave_granted_current_year;
    const newLeave = 15; // 입사 12개월 완성시 무조건 15개

    // 지급연차만 업데이트 (사용연차/잔여연차는 별도 함수에서 처리)
    const { error: updateError } = await supabase
      .from('employees')
      .update({
        annual_leave_granted_current_year: newLeave
      })
      .eq('id', employee.id);

    // 사용연차 및 잔여연차는 전용 함수에서 처리
    if (!updateError) {
      await callUpdateUsedAnnualLeave(supabase, employee.email, new Date(anniversaryDate).getFullYear(), authHeader);
    }

    if (updateError) {
      throw new Error(`연차 업데이트 실패: ${updateError.message}`);
    }


    return {
      employeeId: employee.id,
      employeeName: employee.name,
      joinDate: employee.join_date,
      anniversaryDate,
      previousLeave,
      newLeave,
      usedLeave: 0, // 별도 함수에서 계산
      newRemainingLeave: newLeave, // 별도 함수에서 재계산됨
      message: `입사 12개월 완성! 연차 ${previousLeave}개 → ${newLeave}개로 업데이트`
    };

  } catch (error) {
    console.error(`${employee.name} 기념일 처리 실패:`, error);
    return {
      employeeId: employee.id,
      employeeName: employee.name,
      joinDate: employee.join_date,
      anniversaryDate,
      previousLeave: employee.annual_leave_granted_current_year,
      newLeave: employee.annual_leave_granted_current_year,
      usedLeave: 0,
      newRemainingLeave: employee.remaining_annual_leave,
      message: `처리 실패: ${error instanceof Error ? error.message : '알 수 없는 오류'}`
    };
  }
}

// 중복 제거: update_used_annual_leave 함수 호출
async function callUpdateUsedAnnualLeave(
  supabase: any,
  userEmail: string,
  targetYear: number,
  authHeader: string
): Promise<void> {
  try {
    // update_used_annual_leave Edge Function 호출
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const functionUrl = `${supabaseUrl}/functions/v1/update_used_annual_leave`;
    
    const response = await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader, // 사용자 토큰 사용
      },
      body: JSON.stringify({
        userEmail,
        targetYear,
      }),
    });

    if (!response.ok) {
      console.error('사용연차 업데이트 호출 실패:', response.status);
    } else {
    }
  } catch (error) {
    console.error('사용연차 업데이트 중 오류:', error);
  }
}