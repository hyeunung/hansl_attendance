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

    // 승인된 모든 leave 데이터 조회 (RLS 우회)
    const { data: leaves, error: leaveError } = await supabase
      .from('leave')
      .select('*')
      .eq('status', 'approved')
      .order('start_date', { ascending: true })

    if (leaveError) {
      throw leaveError
    }

    // 직원 정보 조회
    const { data: employees, error: empError } = await supabase
      .from('employees')
      .select('id, email, name, department, attendance_role, purchase_role')

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
        attendance_role: null,
        purchase_role: null
      }

      return {
        ...leave,
        employees: employeeData,
        name: leave.name || employeeData.name
      }
    }) || []

    // 승인된 business_trips 조회
    const { data: businessTrips, error: btError } = await supabase
      .from('business_trips')
      .select('*')
      .in('approval_status', ['approved', 'completed'])
      .order('trip_start_date', { ascending: true })

    if (btError) {
      console.error('business_trips 조회 오류:', btError)
    }

    // business_trips를 leave 형식으로 변환
    const enrichedBusinessTrips = (businessTrips || []).map((bt) => {
      const requester = employees?.find((emp) => emp.id === bt.requester_id)
      const requesterEmail = requester?.email || ''
      const employeeData = employeeMap.get(requesterEmail) || {
        name: requester?.name || '알 수 없음',
        email: requesterEmail,
        department: bt.request_department,
        attendance_role: null,
        purchase_role: null
      }
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
        '출장자': allTravelers,
        status: 'approved',
        created_at: bt.created_at,
        trip_code: bt.trip_code,
        is_business_trip: true,
        employees: employeeData
      }
    })

    const allData = [...enrichedLeaves, ...enrichedBusinessTrips]
    allData.sort((a, b) => new Date(a.start_date).getTime() - new Date(b.start_date).getTime())

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