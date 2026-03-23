import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface UpdateUsedLeaveRequest {
  userEmail?: string; // 특정 직원만 업데이트
  targetYear?: number; // 업데이트할 년도
  forceUpdate?: boolean; // 강제 업데이트
}

interface Employee {
  id: number;
  email: string;
  name: string;
  annual_leave_granted_current_year: number;
  used_annual_leave: number;
  remaining_annual_leave: number;
}

interface UpdateResult {
  employeeId: number;
  employeeName: string;
  employeeEmail: string;
  previousUsed: number;
  newUsed: number;
  newRemaining: number;
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

    // 🔒 인증 확인
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

    // Parse request body
    const requestBody = req.method === 'POST' ? await req.json() : {};
    const { userEmail, targetYear, forceUpdate = false }: UpdateUsedLeaveRequest = requestBody;

    // 권한 확인
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

    // 관리자 권한 확인
    const isAdmin = currentEmployee.roles && 
                   Array.isArray(currentEmployee.roles) && 
                   currentEmployee.roles.includes('admin');

    // 권한 검사
    if (userEmail) {
      // 특정 직원 업데이트: 본인이거나 관리자여야 함
      if (user.email !== userEmail && !isAdmin) {
        return new Response(
          JSON.stringify({ success: false, error: '다른 직원의 연차 정보를 수정할 권한이 없습니다.' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    } else {
      // 전체 직원 업데이트: 관리자만 가능
      if (!isAdmin) {
        return new Response(
          JSON.stringify({ success: false, error: '전체 직원 연차 업데이트는 관리자만 가능합니다.' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 한국 시간 기준 년도 계산
    const now = new Date();
    const kstOffset = 9 * 60 * 60 * 1000; // UTC+9
    const kstDate = new Date(now.getTime() + kstOffset);
    
    const updateYear = targetYear || kstDate.getFullYear();


    // 업데이트 대상 직원 조회
    let employeeQuery = supabase
      .from('employees')
      .select('id, email, name, annual_leave_granted_current_year, used_annual_leave, remaining_annual_leave')
      .not('email', 'is', null);

    if (userEmail) {
      employeeQuery = employeeQuery.eq('email', userEmail);
    }

    const { data: employees, error: employeeError } = await employeeQuery;

    if (employeeError) {
      throw new Error(`직원 조회 실패: ${employeeError.message}`);
    }

    if (!employees || employees.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: '업데이트할 직원이 없습니다.',
          results: []
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }


    const results: UpdateResult[] = [];
    let successCount = 0;
    let errorCount = 0;

    // 각 직원별로 사용연차 업데이트
    for (const employee of employees) {
      try {
        const result = await updateEmployeeUsedLeave(
          supabase, 
          employee, 
          updateYear
        );
        results.push(result);
        successCount++;
      } catch (error) {
        console.error(`${employee.name} 업데이트 실패:`, error);
        results.push({
          employeeId: employee.id,
          employeeName: employee.name,
          employeeEmail: employee.email,
          previousUsed: employee.used_annual_leave || 0,
          newUsed: employee.used_annual_leave || 0,
          newRemaining: employee.remaining_annual_leave || 0,
          message: `업데이트 실패: ${error instanceof Error ? error.message : '알 수 없는 오류'}`
        });
        errorCount++;
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `${updateYear}년 사용연차 업데이트 완료 (성공: ${successCount}, 실패: ${errorCount})`,
        summary: {
          totalEmployees: employees.length,
          successCount,
          errorCount,
          targetYear: updateYear
        },
        results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('사용연차 업데이트 중 오류:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : '알 수 없는 오류' 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function updateEmployeeUsedLeave(
  supabase: any,
  employee: Employee,
  targetYear: number
): Promise<UpdateResult> {
      const previousUsed = employee.used_annual_leave || 0;

  // 해당 년도의 승인된 연차 사용량 계산
  const { data: usedLeave, error: leaveError } = await supabase
    .from('leave')
    .select('type, start_date, end_date')
    .eq('user_email', employee.email)
    .eq('status', 'approved')
    .gte('start_date', `${targetYear}-01-01`)
    .lte('start_date', `${targetYear}-12-31`);

  if (leaveError) {
    throw new Error(`연차 사용 기록 조회 실패: ${leaveError.message}`);
  }

  let totalUsed = 0;
  if (usedLeave) {
    for (const leave of usedLeave) {
      if (leave.type === 'annual') {
        const startDate = new Date(leave.start_date);
        const endDate = new Date(leave.end_date);
        const days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;
        totalUsed += days;
      } else if (leave.type === 'half_am' || leave.type === 'half_pm') {
        totalUsed += 0.5;
      }
    }
  }

  // 잔여연차 계산
  const grantedLeave = employee.annual_leave_granted_current_year || 0;
  const remainingLeave = Math.max(0, grantedLeave - totalUsed);

  // DB 업데이트
  const { error: updateError } = await supabase
    .from('employees')
    .update({
              used_annual_leave: totalUsed,
      remaining_annual_leave: remainingLeave
    })
    .eq('id', employee.id);

  if (updateError) {
    throw new Error(`DB 업데이트 실패: ${updateError.message}`);
  }


  return {
    employeeId: employee.id,
    employeeName: employee.name,
    employeeEmail: employee.email,
    previousUsed,
    newUsed: totalUsed,
    newRemaining: remainingLeave,
    message: `사용연차 ${previousUsed} → ${totalUsed}로 업데이트 완료`
  };
}