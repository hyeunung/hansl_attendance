// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Update Half AM Status Function Started")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function updateHalfAmStatus() {
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

  // 4. 13:30 이후에만 실행
  if (currentHour < 13 || (currentHour === 13 && currentMinute < 30)) {
    console.log('⏰ Not yet 13:30, skipping update')
    return {
      success: true,
      message: 'Not yet 13:30, no updates needed',
      date: today,
      time: `${currentHour}:${currentMinute}`
    }
  }

  try {
    // 5. 오늘의 오전반차 직원 중 아직 출근하지 않은 사람 조회
    const { data: halfAmRecords, error: fetchError } = await supabase
      .from('attendance_records')
      .select('id, employee_id, employee_name, user_email, status, clock_in')
      .eq('date', today)
      .eq('status', '오전반차')
      .is('clock_in', null)  // 아직 출근하지 않은 경우

    if (fetchError) {
      console.warn(`Warning: Failed to fetch half_am records: ${fetchError.message}`)
      return {
        success: false,
        error: fetchError.message
      }
    }

    if (!halfAmRecords || halfAmRecords.length === 0) {
      console.log('✅ No half_am employees without clock_in for today')
      return {
        success: true,
        message: 'No half_am employees to update',
        date: today
      }
    }

    console.log(`🏖️ Found ${halfAmRecords.length} half_am employees without clock_in`)

    // 6. 오전반차 직원들을 미출근으로 변경
    let updatedCount = 0
    for (const record of halfAmRecords) {
      const { error: updateError } = await supabase
        .from('attendance_records')
        .update({
          status: '미출근',
          updated_at: new Date().toISOString()
        })
        .eq('id', record.id)

      if (updateError) {
        console.error(`Failed to update record for ${record.employee_name}: ${updateError.message}`)
      } else {
        updatedCount++
        console.log(`✅ Updated ${record.employee_name} (${record.user_email}) from 오전반차 to 미출근`)
      }
    }

    console.log(`✅ Successfully updated ${updatedCount} records from 오전반차 to 미출근 status`)
    
    return {
      success: true,
      message: `Successfully updated ${updatedCount} records to 미출근 status`,
      updated: updatedCount,
      total: halfAmRecords.length,
      date: today,
      time: `${currentHour}:${currentMinute}`
    }

  } catch (error) {
    console.error('❌ Error in updateHalfAmStatus:', error)
    throw error
  }
}

Deno.serve(async (req) => {
  // CORS preflight 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log(`🚀 Starting half AM status update process...`)
    const result = await updateHalfAmStatus()
    
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

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/update_half_am_status' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/