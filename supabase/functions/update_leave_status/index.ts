import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  // CORS preflight 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('인증 헤더가 없습니다.')
    }

    // 요청 데이터 파싱
    const { id, status } = await req.json()
    
    if (!id || !status) {
      throw new Error('필수 파라미터가 누락되었습니다.')
    }

    if (!['approved', 'rejected'].includes(status)) {
      throw new Error('유효하지 않은 상태값입니다.')
    }

    // Service role client 생성 (RLS 우회)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 먼저 현재 사용자가 관리자 권한이 있는지 확인
    // Anon key를 사용하여 사용자 정보 확인
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    })
    
    const { data: userData, error: userError } = await userClient.auth.getUser()
    if (userError) {
      console.error('사용자 인증 실패:', userError)
      throw new Error('Auth session missing!')
    }

    const userEmail = userData.user.email
    console.log(`🔍 권한 확인: ${userEmail}이 ID ${id}를 ${status}로 변경 시도`)

    // 사용자의 관리자 권한 확인
    const { data: employee, error: empError } = await supabase
      .from('employees')
      .select('attendance_role, department')
      .eq('email', userEmail)
      .single()

    if (empError) {
      console.error('직원 정보 조회 실패:', empError)
      throw new Error('권한을 확인할 수 없습니다.')
    }

    const attendanceRoles = employee.attendance_role || []
    const isSuperAdmin = attendanceRoles.includes('superadmin')
    const isAdmin = attendanceRoles.includes('admin')
    const isManager = attendanceRoles.some(role => role.endsWith('_manager'))

    if (!isSuperAdmin && !isAdmin && !isManager) {
      throw new Error('승인/반려 권한이 없습니다.')
    }

    console.log(`🔑 사용자 권한: ${JSON.stringify(attendanceRoles)}`)
    console.log(`📋 권한 체크 결과: superadmin=${isSuperAdmin}, admin=${isAdmin}, manager=${isManager}`)

    // 대상 leave 정보 조회 (JOIN 없이 간단하게)
    const { data: leaveData, error: leaveError } = await supabase
      .from('leave')
      .select('*')
      .eq('id', id)
      .single()

    if (leaveError) {
      console.error('Leave 정보 조회 실패:', leaveError)
      throw new Error('신청 정보를 찾을 수 없습니다.')
    }
    
    console.log(`📋 Leave 데이터 조회 성공: ID ${id}, User: ${leaveData.user_email}, Type: ${leaveData.type}`)
    
    // 신청자의 부서 정보 별도 조회
    const { data: requesterEmployee, error: requesterEmpError } = await supabase
      .from('employees')
      .select('department')
      .eq('email', leaveData.user_email)
      .single()
    
    if (requesterEmpError) {
      console.error('신청자 부서 정보 조회 실패:', requesterEmpError)
    } else {
      leaveData.department = requesterEmployee.department
      console.log(`👤 신청자 부서: ${requesterEmployee.department}`)
    }

    // 신청자의 권한도 확인
    const { data: requesterData, error: requesterError } = await supabase
      .from('employees')
      .select('attendance_role')
      .eq('email', leaveData.user_email)
      .single()
    
    if (requesterError || !requesterData) {
      throw new Error('신청자 정보를 찾을 수 없습니다.')
    }
    
    const requesterRoles = requesterData.attendance_role || []
    const isRequesterSuperAdmin = requesterRoles.includes('superadmin')

    // 권한별 승인 가능 범위 체크
    if (isSuperAdmin) {
      // superadmin은 모든 직원의 신청 승인 가능 (제한 없음)
      console.log(`✅ superadmin → 모든 직원 승인 권한 확인`)
      
    } else if (isAdmin) {
      // admin은 모든 부서 가능 (superadmin 제외)
      if (isRequesterSuperAdmin) {
        throw new Error('admin은 superadmin 신청을 승인할 수 없습니다.')
      }
      console.log(`✅ admin 승인 권한 확인 (non-superadmin 대상)`)
      
    } else if (isManager) {
      // 부서 관리자는 해당 부서만 (superadmin 제외)
      if (isRequesterSuperAdmin) {
        throw new Error('부서 관리자는 superadmin 신청을 승인할 수 없습니다.')
      }
      
      const targetDepartment = leaveData.department
      let hasPermission = false

      // 각 부서 매니저별 권한 체크
      if (attendanceRoles.includes('개발팀_manager')) {
        hasPermission = ['개발1팀', '개발2팀'].includes(targetDepartment)
      } else if (attendanceRoles.includes('개발3팀_manager')) {
        hasPermission = targetDepartment === '개발3팀'
      } else if (attendanceRoles.includes('CAD_manager')) {
        hasPermission = targetDepartment === 'CAD'
      } else if (attendanceRoles.includes('연구소_manager')) {
        hasPermission = targetDepartment === '연구소'
      } else if (attendanceRoles.includes('경영지원팀_manager')) {
        hasPermission = targetDepartment === '경영지원팀'
      } else if (attendanceRoles.includes('기획팀_manager')) {
        hasPermission = targetDepartment === '기획팀'
      } else if (attendanceRoles.includes('영업팀_manager')) {
        hasPermission = targetDepartment === '영업팀'
      }

      if (!hasPermission) {
        throw new Error('해당 부서의 승인 권한이 없습니다.')
      }
      
      console.log(`✅ ${targetDepartment} 관리자 승인 권한 확인`)
    }

    // Service role로 leave 상태 업데이트 (RLS 우회) - status만 업데이트
    const { data: updateResult, error: updateError } = await supabase
      .from('leave')
      .update({ status: status })
      .eq('id', id)
      .select()

    if (updateError) {
      console.error('Leave 업데이트 실패:', updateError)
      throw updateError
    }

    console.log(`✅ Leave 상태 업데이트 성공: ID ${id} -> ${status}`)
    console.log('업데이트 결과:', updateResult)

    // 신청자에게 승인/반려 결과 알림 발송
    try {
      const leaveType = leaveData.type === 'annual' ? '연차' : '출장'
      const statusKorean = status === 'approved' ? '승인' : '반려'
      const approverName = employee.name || userEmail.split('@')[0]
      
      console.log(`📱 신청자 ${leaveData.user_email}에게 ${statusKorean} 알림 발송 시작`)
      
      await supabase.functions.invoke('send_fcm_notification', {
        body: {
          type: 'user',
          user_email: leaveData.user_email,
          title: `${leaveType} ${statusKorean} 알림`,
          body: status === 'approved' 
            ? `${leaveType} 신청이 승인되었습니다. (승인자: ${approverName})`
            : `${leaveType} 신청이 반려되었습니다. (처리자: ${approverName})`,
          data: {
            type: 'leave_result',
            leave_id: id.toString(),
            status: status,
            leave_type: leaveData.type
          }
        }
      })
      
      console.log(`✅ 신청자 알림 발송 완료: ${leaveData.user_email} → ${statusKorean}`)
    } catch (notificationError) {
      console.error('❌ 신청자 알림 발송 실패:', notificationError)
      // 알림 실패해도 메인 프로세스는 성공으로 처리
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Leave 상태가 ${status}로 변경되었습니다.`,
        data: updateResult
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    console.error('Leave 상태 업데이트 오류:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Leave 상태 업데이트 실패'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})