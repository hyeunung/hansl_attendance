// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'


const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface Employee {
  id: string;
  email: string;
  name: string;
  department: string;
}

interface LeaveRecord {
  user_email: string;
  type: string;
  start_date: string;
  end_date: string;
  status: string;
  reason?: string;
  출장자?: string[];  // 출장자 + 동행자 배열
}

async function createDailyAttendanceRecords() {
  // 1. 환경변수 검증
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  
  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing required environment variables: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
  }

  // 2. Supabase 클라이언트 초기화 (Service Role Key 사용)
  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  // 3. 한국 시간으로 오늘 날짜 계산
  const now = new Date()
  const kstOffset = 9 * 60 * 60 * 1000 // UTC+9
  const kstDate = new Date(now.getTime() + kstOffset)
  const today = kstDate.toISOString().split('T')[0]
  
  // 3-1. 주말 체크 (0: 일요일, 6: 토요일)
  const dayOfWeek = kstDate.getDay()
  const isWeekend = dayOfWeek === 0 || dayOfWeek === 6

  try {
    // 3-2. 공휴일 체크
    const { data: holidays, error: holidayError } = await supabase
      .from('holidays')
      .select('date')
      .eq('date', today)
      .limit(1)
    
    if (holidayError) {
      console.warn(`Warning: Failed to check holidays: ${holidayError.message}`)
    }
    
    const isHoliday = holidays && holidays.length > 0

    // 4. 재직자만 조회 (is_active = true)
    const { data: employees, error: employeesError } = await supabase
      .from('employees')
      .select('id, email, name, department')
      .eq('is_active', true)
    
    if (employeesError) {
      throw new Error(`Failed to fetch employees: ${employeesError.message}`)
    }

    if (!employees || employees.length === 0) {
      throw new Error('No employees found')
    }


    // 5. 오늘의 승인된 연차/출장 기록 조회 (출장자 필드 포함)
    const { data: leaveRecords, error: leaveError } = await supabase
      .from('leave')
      .select('user_email, type, start_date, end_date, status, reason, 출장자')
      .eq('status', 'approved')
      .lte('start_date', today)
      .gte('end_date', today)

    if (leaveError) {
      console.warn(`Warning: Failed to fetch leave records: ${leaveError.message}`)
    }

    const leaveMap = new Map<string, LeaveRecord>()
    const companionEmailMap = new Map<string, string>() // 동행자 이메일 -> 출장 타입
    
    if (leaveRecords) {
      // 출장자 이름 수집 (출장자 필드에서)
      const travelerNames = new Set<string>()
      
      leaveRecords.forEach((leave: LeaveRecord) => {
        leaveMap.set(leave.user_email, leave)
        
        // 출장인 경우 출장자 배열에서 모든 이름 수집
        if (leave.type === 'biztrip' && leave.출장자 && leave.출장자.length > 0) {
          leave.출장자.forEach(name => travelerNames.add(name))
        }
      })
      
      // 출장자 이름으로 이메일 찾기 (비동기 처리)
      if (travelerNames.size > 0) {
        const travelerNameArray = Array.from(travelerNames)
        const { data: travelerEmployees } = await supabase
          .from('employees')
          .select('email, name')
          .in('name', travelerNameArray)
        
        if (travelerEmployees) {
          travelerEmployees.forEach((emp: { email: string; name: string }) => {
            companionEmailMap.set(emp.email, 'biztrip')
          })
        }
      }
    }

    // 6. 각 직원에 대해 출근 기록 생성
    const force8amNames = new Set<string>(['정영수', '황연순']);
    const attendanceRecords = employees.map((employee: Employee) => {
      const leave = leaveMap.get(employee.email)
      const companionType = companionEmailMap.get(employee.email) // 동행자 출장 체크
      let status: string | null = null // 기본값 null로 변경
      let clockIn: string | null = null
      
      // 주말이나 공휴일이면 status를 null로 유지
      if (isWeekend || isHoliday) {
        status = null
      } else if (leave) {
        // 평일이고 휴가가 있는 경우
        switch (leave.type) {
          case 'annual':
            status = '연차'
            break
          case 'half_am':
            status = '오전반차'
            // 오전반차는 13:30까지 출근 가능하도록 설정
            clockIn = '13:30:00'  // 기본값으로 오후 1:30 설정
            break
          case 'half_pm':
            status = '오후반차'
            break
          case 'biztrip':
            status = '출장'
            break
          case 'official':
            status = '공가'
            break
          default:
            status = '연차'
        }
      } else if (companionType === 'biztrip') {
        // 동행자 출장 처리
        status = '출장'
      } else if (force8amNames.has(employee.name)) {
        // 휴가가 아닌 평일, 특정 인원은 08:00 고정 기록
        clockIn = '08:00:00'
        status = '출근'  // DB 상태값과 일치하도록 수정
      } else {
        // 평일이고 휴가도 없고 특정 인원도 아닌 경우
        status = '출근 전'
      }

      return {
        date: today,
        employee_id: employee.id,
        employee_name: employee.name,
        user_email: employee.email,
        status: status,
        clock_in: clockIn,
        clock_out: null,
        created_at: new Date().toISOString(),
      }
    })

    // 7. 기존 레코드 확인 및 upsert
    const { data: existingRecords, error: checkError } = await supabase
      .from('attendance_records')
      .select('employee_id')
      .eq('date', today)

    if (checkError) {
      console.warn(`Warning: Failed to check existing records: ${checkError.message}`)
    }

    const existingEmployeeIds = new Set(
      existingRecords?.map(record => record.employee_id) || []
    )

    // 8. 새로운 레코드만 필터링
    const newRecords = attendanceRecords.filter(
      record => !existingEmployeeIds.has(record.employee_id)
    )

    if (newRecords.length === 0) {
      return {
        success: true,
        message: `All ${employees.length} attendance records already exist for ${today}`,
        created: 0,
        existing: employees.length
      }
    }

    // 9. 새로운 레코드 삽입
    const { data: insertedRecords, error: insertError } = await supabase
      .from('attendance_records')
      .insert(newRecords)
      .select()

    if (insertError) {
      throw new Error(`Failed to insert attendance records: ${insertError.message}`)
    }

    
    return {
      success: true,
      message: `Successfully created ${newRecords.length} attendance records for ${today}`,
      created: newRecords.length,
      existing: existingEmployeeIds.size,
      total: employees.length,
      date: today
    }

  } catch (error) {
    console.error('❌ Error in createDailyAttendanceRecords:', error)
    throw error
  }
}

Deno.serve(async (req) => {
  // CORS preflight 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const result = await createDailyAttendanceRecords()
    
    return new Response(
      JSON.stringify(result),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('❌ Function execution failed:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/daily_attendance_seed' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
