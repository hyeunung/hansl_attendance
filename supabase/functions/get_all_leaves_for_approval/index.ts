import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.31.0'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Service role client 생성 (RLS 우회)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // 모든 leave 데이터 조회 (RLS 우회)
    const { data: leaves, error: leaveError } = await supabase
      .from('leave')
      .select('*')
      .order('created_at', { ascending: false })

    if (leaveError) {
      throw leaveError
    }

    // 직원 정보 조회
    const { data: employees, error: empError } = await supabase
      .from('employees')
      .select('id, email, name, department, roles')

    if (empError) {
      throw empError
    }

    // 이메일을 키로 하는 맵 생성
    const employeeMap = new Map()
    employees?.forEach((emp) => {
      employeeMap.set(emp.email, emp)
    })

    // leave 데이터에 직원 정보 추가 (biztrip_migrated 제외)
    const enrichedLeaves = leaves?.filter((leave) => leave.type !== 'biztrip_migrated').map((leave) => {
      const employeeData = employeeMap.get(leave.user_email) || {
        name: leave.name || '알 수 없음',
        email: leave.user_email,
        department: null,
        roles: null
      }

      return {
        ...leave,
        employees: employeeData,
        name: leave.name || employeeData.name,
        department: employeeData.department
      }
    }) || []

    // business_trips 데이터 조회
    const { data: businessTrips, error: btError } = await supabase
      .from('business_trips')
      .select('*')
      .order('created_at', { ascending: false })

    if (btError) {
      console.error('business_trips 조회 오류:', btError)
    }

    // business_trips를 leave 형식으로 변환하여 합산
    const enrichedBusinessTrips = (businessTrips || []).map((bt) => {
      // requester_id로 직원 정보 찾기
      const requester = employees?.find((emp) => emp.id === bt.requester_id)
      const requesterEmail = requester?.email || ''
      const employeeData = employeeMap.get(requesterEmail) || {
        name: requester?.name || '알 수 없음',
        email: requesterEmail,
        department: bt.request_department,
        roles: null
      }

      // companions jsonb → 출장자 배열 변환
      const companionNames = (bt.companions || []).map((c: any) => c.name).filter(Boolean)
      const allTravelers = requester?.name ? [requester.name, ...companionNames] : companionNames

      return {
        id: `bt_${bt.id}`,
        business_trip_id: bt.id,
        user_email: requesterEmail,
        name: requester?.name || '알 수 없음',
        type: 'biztrip',
        start_date: bt.trip_start_date,
        end_date: bt.trip_end_date,
        reason: bt.trip_purpose,
        place: bt.trip_destination,
        transport: null,
        '출장자': allTravelers,
        status: bt.approval_status === 'completed' ? 'approved' : bt.approval_status,
        approved_by: null,
        rejected_by: null,
        approved_at: bt.approved_at,
        rejected_at: null,
        created_at: bt.created_at,
        updated_at: bt.updated_at,
        department: bt.request_department,
        trip_code: bt.trip_code,
        rejection_reason: bt.rejection_reason,
        is_business_trip: true,
        employees: employeeData
      }
    })

    const allData = [...enrichedLeaves, ...enrichedBusinessTrips]
    // 최신순 정렬
    allData.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

    return new Response(
      JSON.stringify({
        success: true,
        data: allData,
        count: allData.length
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )
  } catch (error) {
    console.error('❌ Error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )
  }
})