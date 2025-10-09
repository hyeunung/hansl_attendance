import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Supabase 클라이언트 생성
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )


    // 1. 현재 올해 입사자들 확인
    const currentYear = new Date().getFullYear()
    const { data: currentYearEmployees, error: fetchError } = await supabaseClient
      .from('employees')
      .select('id, email, name, join_date, annual_leave_granted_current_year')
      .not('join_date', 'is', null)
      .gte('join_date', `${currentYear}-01-01`)
      .lte('join_date', `${currentYear}-12-31`)

    if (fetchError) {
      throw new Error(`직원 조회 실패: ${fetchError.message}`)
    }


    let updatedCount = 0
    const results = []

    for (const employee of currentYearEmployees || []) {
      const joinDate = new Date(employee.join_date)
      
      // 입사월 기준으로 연차 계산 (월 단위)
      const joinMonth = joinDate.getMonth() + 1 // 1-12
      const remainingMonths = 13 - joinMonth // 입사월부터 연말까지
      
      // 15일 기준으로 비례 계산
      const calculatedLeave = Math.floor((15 * remainingMonths) / 12)
      
      // 현재 지급된 연차와 다르면 업데이트
      if (employee.annual_leave_granted_current_year !== calculatedLeave) {
        const { error: updateError } = await supabaseClient
          .from('employees')
          .update({
            annual_leave_granted_current_year: calculatedLeave,
            remaining_annual_leave: calculatedLeave
          })
          .eq('id', employee.id)

        if (updateError) {
          console.error(`❌ ${employee.name} 업데이트 실패:`, updateError.message)
          results.push({
            employee: employee.name,
            email: employee.email,
            success: false,
            error: updateError.message
          })
        } else {
          updatedCount++
          results.push({
            employee: employee.name,
            email: employee.email,
            success: true,
            before: employee.annual_leave_granted_current_year,
            after: calculatedLeave
          })
        }
      } else {
        results.push({
          employee: employee.name,
          email: employee.email,
          success: true,
          message: '이미 올바른 값'
        })
      }
    }

    const response = {
      success: true,
      message: `신입 직원 연차 수정 완료: ${updatedCount}명 업데이트`,
      totalEmployees: currentYearEmployees?.length || 0,
      updatedCount,
      results
    }


    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ 오류 발생:', error.message)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})