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
  is_active?: boolean;
}

interface LeaveRecord {
  user_email: string;
  type: string;
  start_date: string;
  end_date: string;
  status: string;
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
  
  console.log(`🕐 Processing date: ${today} (KST)`)

  try {
    // 4. 모든 활성 직원 조회
    const { data: employees, error: employeesError } = await supabase
      .from('employees')
      .select('id, email, name, department, is_active')
      .or('is_active.is.null,is_active.eq.true') // null이거나 true인 경우
    
    if (employeesError) {
      throw new Error(`Failed to fetch employees: ${employeesError.message}`)
    }

    if (!employees || employees.length === 0) {
      throw new Error('No employees found')
    }

    console.log(`👥 Found ${employees.length} active employees`)

    // 5. 오늘의 승인된 연차/출장 기록 조회
    const { data: leaveRecords, error: leaveError } = await supabase
      .from('leave')
      .select('user_email, type, start_date, end_date, status')
      .eq('status', 'approved')
      .lte('start_date', today)
      .gte('end_date', today)

    if (leaveError) {
      console.warn(`Warning: Failed to fetch leave records: ${leaveError.message}`)
    }

    const leaveMap = new Map<string, LeaveRecord>()
    if (leaveRecords) {
      leaveRecords.forEach((leave: LeaveRecord) => {
        leaveMap.set(leave.user_email, leave)
      })
      console.log(`🏖️ Found ${leaveRecords.length} approved leave records for today`)
    }

    // 6. 각 직원에 대해 출근 기록 생성
    const attendanceRecords = employees.map((employee: Employee) => {
      const leave = leaveMap.get(employee.email)
      let status = '출근 전' // 기본 상태
      
      if (leave) {
        switch (leave.type) {
          case 'annual':
            status = '연차'
            break
          case 'half_am':
            status = '오전반차'
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
      }

      return {
        date: today,
        employee_id: employee.id,
        employee_name: employee.name,
        status: status,
        clock_in: null,
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
      console.log(`✅ All attendance records already exist for ${today}`)
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

    console.log(`✅ Successfully created ${newRecords.length} attendance records for ${today}`)
    
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
    console.log(`🚀 Starting daily attendance seed process...`)
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