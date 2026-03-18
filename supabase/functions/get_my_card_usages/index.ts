import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 인증된 사용자 확인
    const authHeader = req.headers.get('authorization')
    if (!authHeader) {
      throw new Error('인증 헤더가 없습니다.')
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      throw new Error('인증 실패')
    }

    // 사용자의 employee id 조회
    const { data: employee, error: empError } = await supabase
      .from('employees')
      .select('id')
      .eq('email', user.email!)
      .single()

    if (empError || !employee) {
      throw new Error('직원 정보를 찾을 수 없습니다.')
    }

    // 한국시간 기준 오늘 날짜
    const now = new Date()
    const kstOffset = 9 * 60 * 60 * 1000
    const kstDate = new Date(now.getTime() + kstOffset)
    const today = kstDate.toISOString().split('T')[0]

    // 본인의 승인된 카드 사용 건 조회
    // 1) 출장 연동 건: 출장 기간 내만
    // 2) 카드 단독 건: 사용 날짜에만
    const { data: cardUsages, error: cuError } = await supabase
      .from('card_usages')
      .select(`
        *,
        business_trips (
          id, trip_code, trip_start_date, trip_end_date, trip_destination, trip_purpose
        ),
        card_usage_receipts (
          id, receipt_url, merchant_name, item_name, total_amount, created_at
        )
      `)
      .eq('requester_id', employee.id)
      .in('approval_status', ['approved', 'settled'])

    if (cuError) {
      throw cuError
    }

    // 날짜 조건 필터링
    const filtered = (cardUsages || []).filter((cu: any) => {
      if (cu.business_trip_id && cu.business_trips) {
        // 출장 연동 건: 출장 기간과 오늘을 비교하지 않고, 전체 보여줌 (현장 업로드이므로)
        return true
      }
      // 카드 단독 건: 전체 보여줌
      return true
    })

    return new Response(
      JSON.stringify({
        success: true,
        data: filtered,
        count: filtered.length
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})
