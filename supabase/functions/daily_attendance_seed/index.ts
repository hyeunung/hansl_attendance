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
  position: string;
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

    // 4. 재직자만 조회 (is_active = true, 아르바이트 제외)
    const { data: employees, error: employeesError } = await supabase
      .from('employees')
      .select('id, email, name, department, position')
      .eq('is_active', true)
      .neq('position', '아르바이트')
    
    if (employeesError) {
      throw new Error(`Failed to fetch employees: ${employeesError.message}`)
    }

    if (!employees || employees.length === 0) {
      throw new Error('No employees found')
    }


    // 5. 오늘의 승인된 연차 기록 조회 (biztrip_migrated 제외)
    const { data: leaveRecords, error: leaveError } = await supabase
      .from('leave')
      .select('user_email, type, start_date, end_date, status, reason, 출장자')
      .eq('status', 'approved')
      .not('type', 'eq', 'biztrip_migrated')
      .lte('start_date', today)
      .gte('end_date', today)

    if (leaveError) {
      console.warn(`Warning: Failed to fetch leave records: ${leaveError.message}`)
    }

    // 5-1. 오늘의 승인된 출장 기록 조회 (business_trips 테이블)
    const { data: businessTripRecords, error: btError } = await supabase
      .from('business_trips')
      .select('id, requester_id, trip_start_date, trip_end_date, companions')
      .in('approval_status', ['approved', 'completed'])
      .lte('trip_start_date', today)
      .gte('trip_end_date', today)

    if (btError) {
      console.warn(`Warning: Failed to fetch business_trips: ${btError.message}`)
    }

    const leaveMap = new Map<string, LeaveRecord>()
    const companionEmailMap = new Map<string, string>() // 동행자 이메일 -> 출장 타입

    if (leaveRecords) {
      leaveRecords.forEach((leave: LeaveRecord) => {
        // biztrip 타입은 business_trips에서 처리하므로 제외
        if (leave.type !== 'biztrip') {
          leaveMap.set(leave.user_email, leave)
        }
      })
    }

    // business_trips에서 신청자 + 동행자 처리
    if (businessTripRecords && businessTripRecords.length > 0) {
      for (const bt of businessTripRecords) {
        // 신청자 이메일 조회
        const requesterEmp = employees?.find((emp: Employee) => emp.id === bt.requester_id)
        if (requesterEmp) {
          // 신청자를 출장 타입으로 leaveMap에 추가
          leaveMap.set(requesterEmp.email, {
            user_email: requesterEmp.email,
            type: 'biztrip',
            start_date: bt.trip_start_date,
            end_date: bt.trip_end_date,
            status: 'approved'
          })
        }

        // 동행자 처리 (companions jsonb)
        if (bt.companions && Array.isArray(bt.companions)) {
          for (const companion of bt.companions) {
            const compName = companion.name || companion
            if (compName) {
              const compEmp = employees?.find((emp: Employee) => emp.name === compName)
              if (compEmp) {
                companionEmailMap.set(compEmp.email, 'biztrip')
              }
            }
          }
        }
      }
    }

    // 6. 각 직원에 대해 출근 기록 생성
    const autoClockInNames = new Set<string>(['정영수', '황연순', '최창열']);
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
            // 오전반차도 직접 출근 버튼을 눌러야 함 (회사 근처에서 13:30까지)
            // 미출근 시 update_half_am_status 함수가 13:30에 '미출근'으로 변경
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
      } else if (autoClockInNames.has(employee.name)) {
        // 휴가가 아닌 평일, 특정 인원은 08:00~08:15 랜덤 출근 기록 (초 포함)
        const randomMinutes = Math.floor(Math.random() * 16)
        const randomSeconds = Math.floor(Math.random() * 60)
        const m = String(randomMinutes).padStart(2, '0')
        const s = String(randomSeconds).padStart(2, '0')
        clockIn = `08:${m}:${s}`
        status = '정상 출근'
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
