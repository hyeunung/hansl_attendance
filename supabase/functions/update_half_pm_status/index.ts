// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Update Half PM Status Function Started")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function updateHalfPmStatus() {
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
  const currentHour = kstDate.getHours()
  const currentMinute = kstDate.getMinutes()
  
  console.log(`🕐 Processing date: ${today} ${currentHour}:${currentMinute} (KST)`)

  // 4. 12:30 이후에만 실행
  if (currentHour < 12 || (currentHour === 12 && currentMinute < 30)) {
    console.log('⏰ Not yet 12:30 PM, skipping update')
    return {
      success: true,
      message: 'Not yet 12:30 PM, no updates needed',
      date: today,
      time: `${currentHour}:${currentMinute}`
    }
  }

  try {
    // 5. 오늘의 승인된 오후반차 기록 조회
    const { data: halfPmLeaves, error: leaveError } = await supabase
      .from('leave')
      .select('user_email, type, start_date, end_date, status')
      .eq('status', 'approved')
      .eq('type', 'half_pm')
      .lte('start_date', today)
      .gte('end_date', today)

    if (leaveError) {
      console.warn(`Warning: Failed to fetch leave records: ${leaveError.message}`)
    }

    if (!halfPmLeaves || halfPmLeaves.length === 0) {
      console.log('✅ No half_pm leaves for today')
      return {
        success: true,
        message: 'No half_pm leaves for today',
        date: today
      }
    }

    console.log(`🏖️ Found ${halfPmLeaves.length} approved half_pm leaves for today`)

    // 6. 오후반차 직원들의 출근 기록 업데이트
    let updatedCount = 0
    for (const leave of halfPmLeaves) {
      const userEmail = leave.user_email

      // 해당 직원의 오늘 출근 기록 조회
      const { data: attendanceRecord, error: fetchError } = await supabase
        .from('attendance_records')
        .select('*')
        .eq('user_email', userEmail)
        .eq('date', today)
        .single()

      if (fetchError || !attendanceRecord) {
        console.warn(`No attendance record found for ${userEmail}`)
        continue
      }

      // 이미 출근한 직원만 오후반차로 상태 변경
      if (attendanceRecord.clock_in && 
          (attendanceRecord.status === '정상 출근' || 
           attendanceRecord.status === '출근' || 
           attendanceRecord.status === '지각')) {
        
        // clock_out을 12:30으로 설정하고 상태를 오후반차로 변경
        const { error: updateError } = await supabase
          .from('attendance_records')
          .update({
            status: '오후반차',
            clock_out: '12:30:00',
            updated_at: new Date().toISOString()
          })
          .eq('id', attendanceRecord.id)

        if (updateError) {
          console.error(`Failed to update record for ${userEmail}: ${updateError.message}`)
        } else {
          updatedCount++
          console.log(`✅ Updated ${userEmail} to 오후반차 status with clock_out at 12:30`)
        }
      } else {
        console.log(`⏭️ Skipping ${userEmail} - not clocked in or already on leave`)
      }
    }

    console.log(`✅ Successfully updated ${updatedCount} records to 오후반차 status`)
    
    return {
      success: true,
      message: `Successfully updated ${updatedCount} records to 오후반차 status`,
      updated: updatedCount,
      total: halfPmLeaves.length,
      date: today
    }

  } catch (error) {
    console.error('❌ Error in updateHalfPmStatus:', error)
    throw error
  }
}

Deno.serve(async (req) => {
  // CORS preflight 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log(`🚀 Starting half PM status update process...`)
    const result = await updateHalfPmStatus()
    
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

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/update_half_pm_status' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/