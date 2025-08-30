import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface MonthlyCheckRequest {
  year?: number;
  month?: number;
  force?: boolean; // 강제 실행 옵션
}

interface Employee {
  id: number;
  email: string;
  name: string;
  join_date: string;
}

interface AttendanceRecord {
  employee_id: number;
  date: string;
  status: string;
  clock_in: string | null;
  clock_out: string | null;
}

interface MonthlyResult {
  employeeId: number;
  employeeName: string;
  year: number;
  month: number;
  workDays: number;
  attendanceDays: number;
  isFullAttendance: boolean;
  earnedLeave: number;
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

    // Parse request body
    const requestBody = req.method === 'POST' ? await req.json() : {};
    const { year, month, force = false }: MonthlyCheckRequest = requestBody;

    // 한국 시간 기준 날짜 계산
    const now = new Date();
    const kstOffset = 9 * 60 * 60 * 1000; // UTC+9
    const kstDate = new Date(now.getTime() + kstOffset);
    
    const targetYear = year || kstDate.getFullYear();
    const targetMonth = month || kstDate.getMonth() + 1;

    console.log(`🕐 월별 만근 체크 시작: ${targetYear}년 ${targetMonth}월`);

    // 신입 직원 조회 (입사년도 = 대상년도)
    const { data: newEmployees, error: employeeError } = await supabase
      .from('employees')
      .select('id, email, name, join_date')
      .gte('join_date', `${targetYear}-01-01`)
      .lte('join_date', `${targetYear}-12-31`);

    if (employeeError) {
      throw new Error(`신입 직원 조회 실패: ${employeeError.message}`);
    }

    if (!newEmployees || newEmployees.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: `${targetYear}년 신입 직원이 없습니다.`,
          results: []
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`👥 신입 직원 ${newEmployees.length}명 발견`);

    const results: MonthlyResult[] = [];

    // 각 신입 직원별로 월별 만근 체크
    for (const employee of newEmployees) {
      const result = await checkMonthlyAttendance(
        supabase, 
        employee, 
        targetYear, 
        targetMonth
      );
      results.push(result);
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `${targetYear}년 ${targetMonth}월 월별 만근 체크 완료`,
        results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('월별 만근 체크 중 오류:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : '알 수 없는 오류' 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function checkMonthlyAttendance(
  supabase: any,
  employee: Employee,
  year: number,
  month: number
): Promise<MonthlyResult> {
  try {
    const joinDate = new Date(employee.join_date);
    const employeeJoinMonth = joinDate.getMonth() + 1;
    
    // 입사월 이전은 체크하지 않음
    if (month < employeeJoinMonth) {
      return {
        employeeId: employee.id,
        employeeName: employee.name,
        year,
        month,
        workDays: 0,
        attendanceDays: 0,
        isFullAttendance: false,
        earnedLeave: 0,
        message: '입사 이전 기간으로 체크 안함'
      };
    }

    // 해당 월의 근무일수 계산 (주말 제외)
    const workDays = getWorkDaysInMonth(year, month);
    
    // 실제 출근일수 확인
    const attendanceDays = await getActualAttendanceDays(
      supabase, 
      employee.id, 
      year, 
      month
    );

    // 만근 여부 판단 (90% 이상 출근)
    const attendanceRate = attendanceDays / workDays;
    const isFullAttendance = attendanceRate >= 0.9; // 90% 이상을 만근으로 간주
    const earnedLeave = isFullAttendance ? 1 : 0;

    // monthly_attendance 테이블 업데이트
    await updateMonthlyAttendance(
      supabase,
      employee.id,
      year,
      month,
      workDays,
      attendanceDays,
      isFullAttendance,
      earnedLeave
    );

    return {
      employeeId: employee.id,
      employeeName: employee.name,
      year,
      month,
      workDays,
      attendanceDays,
      isFullAttendance,
      earnedLeave,
      message: isFullAttendance 
        ? `만근 달성! 연차 ${earnedLeave}개 지급`
        : `만근 미달성 (${attendanceDays}/${workDays}일 출근)`
    };

  } catch (error) {
    console.error(`${employee.name} 월별 체크 실패:`, error);
    return {
      employeeId: employee.id,
      employeeName: employee.name,
      year,
      month,
      workDays: 0,
      attendanceDays: 0,
      isFullAttendance: false,
      earnedLeave: 0,
      message: `체크 실패: ${error instanceof Error ? error.message : '알 수 없는 오류'}`
    };
  }
}

function getWorkDaysInMonth(year: number, month: number): number {
  const firstDay = new Date(year, month - 1, 1);
  const lastDay = new Date(year, month, 0);
  let workDays = 0;

  for (let date = new Date(firstDay); date <= lastDay; date.setDate(date.getDate() + 1)) {
    const dayOfWeek = date.getDay();
    // 월요일(1) ~ 금요일(5)만 근무일로 계산
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      workDays++;
    }
  }

  return workDays;
}

async function getActualAttendanceDays(
  supabase: any,
  employeeId: number,
  year: number,
  month: number
): Promise<number> {
  // attendance_records 테이블에서 해당 직원의 해당 월 출근 기록 확인
  const startDate = `${year}-${month.toString().padStart(2, '0')}-01`;
  const endDate = `${year}-${month.toString().padStart(2, '0')}-${new Date(year, month, 0).getDate()}`;

  const { data: attendanceRecords, error } = await supabase
    .from('attendance_records')
    .select('date, status, clock_in, clock_out')
    .eq('employee_id', employeeId)
    .gte('date', startDate)
    .lte('date', endDate);

  if (error) {
    console.error('출근 기록 조회 실패:', error);
    return 0;
  }

  if (!attendanceRecords) {
    return 0;
  }

  // 정상 출근한 날짜만 카운트
  let attendanceDays = 0;
  for (const record of attendanceRecords) {
    // 출근 기록이 있고, 연차/출장이 아닌 경우
    if (record.clock_in && !['연차', '출장', '공가'].includes(record.status)) {
      attendanceDays++;
    }
    // 승인된 연차/출장도 출근으로 간주
    else if (['연차', '출장'].includes(record.status)) {
      attendanceDays++;
    }
  }

  return attendanceDays;
}

async function updateMonthlyAttendance(
  supabase: any,
  employeeId: number,
  year: number,
  month: number,
  workDays: number,
  attendanceDays: number,
  isFullAttendance: boolean,
  earnedLeave: number
): Promise<void> {
  // monthly_attendance 테이블 업데이트 (UPSERT)
  const { error } = await supabase
    .from('monthly_attendance')
    .upsert({
      employee_id: employeeId,
      year,
      month,
      work_days: workDays,
      attendance_days: attendanceDays,
      is_full_attendance: isFullAttendance,
      earned_leave_days: earnedLeave,
      updated_at: new Date().toISOString()
    }, {
      onConflict: 'employee_id,year,month'
    });

  if (error) {
    throw new Error(`월별 출근 기록 업데이트 실패: ${error.message}`);
  }

  console.log(`✅ ${employeeId}번 직원 ${year}년 ${month}월 기록 업데이트 완료`);
}