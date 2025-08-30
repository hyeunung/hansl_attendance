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
      .select('email, name, role, is_admin, department, attendance_role')

    if (empError) {
      throw empError
    }

    // 이메일을 키로 하는 맵 생성
    const employeeMap = new Map()
    employees?.forEach((emp) => {
      employeeMap.set(emp.email, emp)
    })

    // leave 데이터에 직원 정보 추가
    const enrichedLeaves = leaves?.map((leave) => {
      const employeeData = employeeMap.get(leave.user_email) || {
        name: leave.name || '알 수 없음',
        email: leave.user_email,
        department: null,
        role: null,
        is_admin: false,
        attendance_role: null
      }

      return {
        ...leave,
        employees: employeeData,
        // 직원 이름이 없으면 employees에서 가져오기
        name: leave.name || employeeData.name
      }
    }) || []

    console.log(`✅ 달력용 승인된 leave 조회 완료: ${enrichedLeaves.length}건`)

    return new Response(
      JSON.stringify({
        success: true,
        data: enrichedLeaves,
        count: enrichedLeaves.length
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