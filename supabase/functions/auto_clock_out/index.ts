// 매일 23:59에 실행되어 퇴근 처리를 하지 않은 직원들을 자동으로 퇴근 처리하는 함수
// - 일반 직원: 18:00 퇴근
// - 오후반차 직원: 12:30 퇴근

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function autoClockOut() {
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
  const kstNow = new Date(now.getTime() + kstOffset)
  const today = kstNow.toISOString().split('T')[0]
  
  console.log(`[자동 퇴근 처리] 실행 시간: ${kstNow.toISOString()} (KST)`)
  console.log(`[자동 퇴근 처리] 처리 날짜: ${today}`)

  // 4. 출근했지만 퇴근하지 않은 직원 조회
  const { data: missingClockOuts, error: selectError } = await supabase
    .from('attendance_records')
    .select('*')
    .eq('date', today)
    .not('clock_in', 'is', null)
    .is('clock_out', null)

  if (selectError) {
    console.error('[자동 퇴근 처리] 조회 오류:', selectError)
    throw selectError
  }

  if (!missingClockOuts || missingClockOuts.length === 0) {
    console.log('[자동 퇴근 처리] 퇴근 미처리 직원 없음')
    return {
      success: true,
      message: '퇴근 미처리 직원 없음',
      processed: 0
    }
  }

  console.log(`[자동 퇴근 처리] 퇴근 미처리 직원 수: ${missingClockOuts.length}명`)

  // 5. 오늘의 오후반차 신청자 조회
  const { data: halfPmLeaves, error: leaveError } = await supabase
    .from('leaves')
    .select('employee_id')
    .eq('status', 'approved')
    .eq('type', 'half_pm')
    .eq('start_date', today)

  if (leaveError) {
    console.error('[자동 퇴근 처리] 오후반차 조회 오류:', leaveError)
  }

  const halfPmEmployeeIds = halfPmLeaves?.map(leave => leave.employee_id) || []
  console.log(`[자동 퇴근 처리] 오후반차 직원 수: ${halfPmEmployeeIds.length}명`)

  // 6. 각 직원을 적절한 시간으로 퇴근 처리
  const updatePromises = missingClockOuts.map(async (record) => {
    // 오후반차 직원인지 확인
    const isHalfPm = halfPmEmployeeIds.includes(record.employee_id)
    const clockOutTime = isHalfPm ? '12:30:00' : '18:00:00'
    const remarks = isHalfPm 
      ? '자동 퇴근 처리 (23:59) - 오후반차' 
      : '자동 퇴근 처리 (23:59)'

    const { error: updateError } = await supabase
      .from('attendance_records')
      .update({
        clock_out: clockOutTime,
        status: '퇴근',
        updated_at: now.toISOString(),
        remarks: remarks
      })
      .eq('id', record.id)

    if (updateError) {
      console.error(`[자동 퇴근 처리] ${record.employee_name} 업데이트 실패:`, updateError)
      return { success: false, employee: record.employee_name, error: updateError }
    }

    console.log(`[자동 퇴근 처리] ${record.employee_name} - ${clockOutTime} 퇴근 처리 완료 ${isHalfPm ? '(오후반차)' : ''}`)
    return { success: true, employee: record.employee_name, time: clockOutTime, isHalfPm }
  })

  const results = await Promise.allSettled(updatePromises)
  const successCount = results.filter(r => r.status === 'fulfilled' && r.value.success).length
  const failedEmployees = results
    .filter(r => r.status === 'fulfilled' && !r.value.success)
    .map(r => r.value.employee)

  console.log(`[자동 퇴근 처리] 완료 - 성공: ${successCount}명, 실패: ${failedEmployees.length}명`)
  
  if (failedEmployees.length > 0) {
    console.error(`[자동 퇴근 처리] 실패한 직원: ${failedEmployees.join(', ')}`)
  }

  return {
    success: true,
    message: `자동 퇴근 처리 완료`,
    processed: successCount,
    failed: failedEmployees.length,
    failedEmployees: failedEmployees
  }
}

Deno.serve(async (req) => {
  // CORS preflight 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const result = await autoClockOut()
    
    return new Response(
      JSON.stringify(result),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
        status: 200,
      },
    )
  } catch (error) {
    console.error('[자동 퇴근 처리] 오류:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
        status: 500,
      },
    )
  }
})
