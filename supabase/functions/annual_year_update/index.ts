import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface YearUpdateRequest {
  targetYear?: number; // 업데이트할 년도
  dryRun?: boolean; // 실제 업데이트 없이 시뮬레이션만
}

interface Employee {
  id: number;
  email: string;
  name: string;
  join_date: string;
  annual_leave_granted_current_year: number;
  remaining_annual_leave: number;
}

interface YearUpdateResult {
  employeeId: number;
  employeeName: string;
  joinDate: string;
  previousServiceYears: number;
  newServiceYears: number;
  previousServiceLevel: string;
  newServiceLevel: string;
  previousLeave: number;
  newLeave: number;
  calculationMethod: string;
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

    // 🔒 관리자 인증 확인 (년도별 연차 업데이트는 관리자만 가능)
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
      .select('email, attendance_role')
      .eq('email', user.email)
      .single();

    if (empError || !currentEmployee) {
      return new Response(
        JSON.stringify({ success: false, error: '직원 정보를 찾을 수 없습니다.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const isAdmin = currentEmployee.attendance_role && 
                   Array.isArray(currentEmployee.attendance_role) && 
                   currentEmployee.attendance_role.includes('admin');

    if (!isAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: '년도별 연차 업데이트는 관리자만 실행할 수 있습니다.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Parse request body
    const requestBody = req.method === 'POST' ? await req.json() : {};
    const { targetYear, dryRun = false }: YearUpdateRequest = requestBody;

    // 한국 시간 기준 년도 계산
    const now = new Date();
    const kstOffset = 9 * 60 * 60 * 1000; // UTC+9
    const kstDate = new Date(now.getTime() + kstOffset);
    
    const updateYear = targetYear || kstDate.getFullYear();


    // 모든 직원 조회 (입사일이 있는 직원만)
    const { data: allEmployees, error: employeeError } = await supabase
      .from('employees')
      .select('id, email, name, join_date, annual_leave_granted_current_year, remaining_annual_leave')
      .not('join_date', 'is', null)
      .order('join_date');

    if (employeeError) {
      throw new Error(`직원 조회 실패: ${employeeError.message}`);
    }

    if (!allEmployees || allEmployees.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: '업데이트할 직원이 없습니다.',
          results: []
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }


    const results: YearUpdateResult[] = [];
    let successCount = 0;
    let errorCount = 0;

    // 각 직원별로 연차 업데이트
    for (const employee of allEmployees) {
      try {
        const result = await updateEmployeeAnnualLeave(
          supabase, 
          employee, 
          updateYear, 
          dryRun
        );
        results.push(result);
        successCount++;
      } catch (error) {
        console.error(`${employee.name} 업데이트 실패:`, error);
        results.push({
          employeeId: employee.id,
          employeeName: employee.name,
          joinDate: employee.join_date,
          previousServiceYears: 0,
          newServiceYears: 0,
          previousServiceLevel: '',
          newServiceLevel: '',
          previousLeave: employee.annual_leave_granted_current_year,
          newLeave: employee.annual_leave_granted_current_year,
          calculationMethod: '실패',
          message: `업데이트 실패: ${error instanceof Error ? error.message : '알 수 없는 오류'}`
        });
        errorCount++;
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `${updateYear}년 연차 일괄 업데이트 완료 (성공: ${successCount}, 실패: ${errorCount})`,
        dryRun,
        summary: {
          totalEmployees: allEmployees.length,
          successCount,
          errorCount
        },
        results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('연차 일괄 업데이트 중 오류:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : '알 수 없는 오류' 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function updateEmployeeAnnualLeave(
  supabase: any,
  employee: Employee,
  targetYear: number,
  dryRun: boolean
): Promise<YearUpdateResult> {
  const joinDate = new Date(employee.join_date);
  const joinYear = joinDate.getFullYear();
  
  // 이전 년차와 새로운 년차 계산
  const previousYear = targetYear - 1;
  const previousServiceYears = previousYear - joinYear;
  const newServiceYears = targetYear - joinYear;
  
  // 서비스 레벨 계산
  const previousServiceLevel = getServiceLevel(previousServiceYears);
  const newServiceLevel = getServiceLevel(newServiceYears);
  
  // 새로운 연차 계산
  const { leave: newLeave, method } = calculateAnnualLeave(newServiceYears);
  
  const result: YearUpdateResult = {
    employeeId: employee.id,
    employeeName: employee.name,
    joinDate: employee.join_date,
    previousServiceYears,
    newServiceYears,
    previousServiceLevel,
    newServiceLevel,
    previousLeave: employee.annual_leave_granted_current_year,
    newLeave,
    calculationMethod: method,
    message: `${previousServiceLevel} → ${newServiceLevel} (${employee.annual_leave_granted_current_year}개 → ${newLeave}개)`
  };

  // 실제 업데이트 수행 (dryRun이 아닌 경우)
  if (!dryRun) {
    await performActualUpdate(supabase, employee.id, newLeave);
  }

  
  return result;
}

function getServiceLevel(serviceYears: number): string {
  if (serviceYears === 0) return '신입';
  if (serviceYears === 1) return '1년차';
  if (serviceYears === 2) return '2년차';
  return `${serviceYears}년차`;
}

function calculateAnnualLeave(serviceYears: number): { leave: number; method: string } {
  if (serviceYears === 0) {
    // 신입: 개별 처리 (15개 기본값)
    return { leave: 15, method: '신입 기본값' };
  } else if (serviceYears === 1 || serviceYears === 2) {
    // 1~2년차: 15개 고정
    return { leave: 15, method: '1~2년차 고정' };
  } else {
    // 3년차 이상: 법정연차 (2년마다 1개씩 추가, 최대 25개)
    const additionalLeave = Math.floor((serviceYears - 1) / 2);
    const totalLeave = Math.min(25, 15 + additionalLeave);
    return { 
      leave: totalLeave, 
      method: `법정연차 (기본15 + 추가${additionalLeave}, 최대25)` 
    };
  }
}

async function performActualUpdate(
  supabase: any,
  employeeId: number,
  newLeave: number
): Promise<void> {
  // 새 년도 연차 업데이트 (지급연차만 업데이트, 사용연차/잔여연차는 0으로 초기화)
  const { error } = await supabase
    .from('employees')
    .update({
      annual_leave_granted_current_year: newLeave,
              used_annual_leave: 0, // 새 년도 시작이므로 사용연차 초기화
      remaining_annual_leave: newLeave // 새 년도 시작이므로 잔여연차 = 지급연차
    })
    .eq('id', employeeId);

  if (error) {
    throw new Error(`DB 업데이트 실패: ${error.message}`);
  }
}