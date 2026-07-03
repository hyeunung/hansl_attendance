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
    const { id, status, is_business_trip, rejection_reason, is_modification } = await req.json()

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
    // Service key를 사용하여 사용자 정보 확인
    const userClient = createClient(supabaseUrl, supabaseServiceKey, {
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

    // 사용자의 관리자 권한 확인
    const { data: employee, error: empError } = await supabase
      .from('employees')
      .select('roles, department')
      .eq('email', userEmail)
      .single()

    if (empError) {
      console.error('직원 정보 조회 실패:', empError)
      throw new Error('권한을 확인할 수 없습니다.')
    }

    const userRoles = employee.roles || []
    const isSuperAdmin = userRoles.includes('superadmin')
    const isAdmin = userRoles.includes('admin')
    const isManager = userRoles.some(role => role.endsWith('_manager'))

    if (!isSuperAdmin && !isAdmin && !isManager) {
      throw new Error('승인/반려 권한이 없습니다.')
    }


    // business_trip인 경우 business_trips 테이블에서 처리
    if (is_business_trip) {
      // business_trip_id에서 숫자만 추출 (bt_123 → 123)
      const btId = typeof id === 'string' ? parseInt(id.replace('bt_', '')) : id

      // 출장 정보 조회 (연장/조기복귀 여부 확인 및 알림용 데이터 획득)
      const { data: tripData, error: fetchError } = await supabase
        .from('business_trips')
        .select('requester_id, requested_end_date, modification_status, trip_code')
        .eq('id', btId)
        .single()

      if (fetchError || !tripData) {
        console.error('출장 정보 조회 실패:', fetchError)
        throw new Error('출장 정보를 찾을 수 없습니다.')
      }

      let updateData: any = {}

      if (is_modification) {
        if (status === 'approved') {
          const { data: approverData } = await supabase
            .from('employees').select('id').eq('email', userEmail).single()
          
          updateData = {
            trip_end_date: tripData.requested_end_date,
            modification_status: tripData.modification_status === 'extension_pending' ? 'extension_approved' : 'early_return_approved',
            modification_approved_by: approverData?.id || null,
            modification_approved_at: new Date().toISOString()
          }
        } else if (status === 'rejected') {
          updateData = {
            modification_status: 'modification_rejected',
            modification_rejected_reason: rejection_reason || null
          }
        }
      } else {
        updateData = { approval_status: status }
        if (status === 'approved') {
          const { data: approverData } = await supabase
            .from('employees').select('id').eq('email', userEmail).single()
          if (approverData) updateData.approved_by = approverData.id
          updateData.approved_at = new Date().toISOString()
        } else if (status === 'rejected') {
          updateData.rejection_reason = rejection_reason || null
        }
      }

      const { data: updateResult, error: updateError } = await supabase
        .from('business_trips')
        .update(updateData)
        .eq('id', btId)
        .select()

      if (updateError) {
        console.error('Business trip 업데이트 실패:', updateError)
        throw updateError
      }

      // 일정 변경(연장/조기복귀) 승인/반려 시 신청자에게 알림 발송
      if (is_modification && tripData.requester_id) {
        try {
          const { data: requester } = await supabase
            .from('employees')
            .select('email, name')
            .eq('id', tripData.requester_id)
            .single()

          if (requester?.email) {
            const modLabel = tripData.modification_status === 'extension_pending' ? '연장' : '조기 복귀'
            const title = status === 'approved' ? `✅ 출장 ${modLabel} 승인` : `❌ 출장 ${modLabel} 반려`
            const body = status === 'approved'
              ? `${requester.name}님의 출장 ${modLabel} 신청이 승인되었습니다. (${tripData.trip_code})`
              : `${requester.name}님의 출장 ${modLabel} 신청이 반려되었습니다. 사유: ${rejection_reason || '없음'} (${tripData.trip_code})`

            await supabase.functions.invoke('send_fcm_notification', {
              body: {
                type: 'user',
                targetEmail: requester.email,
                title: title,
                body: body,
                data: {
                  trip_code: tripData.trip_code,
                  status: status
                }
              }
            })
          }
        } catch (notificationErr) {
          console.warn('출장 변경 알림 발송 실패:', notificationErr)
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: `Business trip 상태가 ${status}로 변경되었습니다.`,
          data: updateResult
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

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
    }

    // 신청자의 권한도 확인
    const { data: requesterData, error: requesterError } = await supabase
      .from('employees')
      .select('roles')
      .eq('email', leaveData.user_email)
      .single()

    if (requesterError || !requesterData) {
      throw new Error('신청자 정보를 찾을 수 없습니다.')
    }

    const requesterRoles = requesterData.roles || []
    const isRequesterSuperAdmin = requesterRoles.includes('superadmin')

    // 권한별 승인 가능 범위 체크
    if (isSuperAdmin) {
      // superadmin은 모든 직원의 신청 승인 가능 (제한 없음)
      
    } else if (isAdmin) {
      // admin은 모든 부서 가능 (superadmin 제외)
      if (isRequesterSuperAdmin) {
        throw new Error('admin은 superadmin 신청을 승인할 수 없습니다.')
      }
      
    } else if (isManager) {
      // 부서 관리자는 해당 부서만 (superadmin 제외)
      if (isRequesterSuperAdmin) {
        throw new Error('부서 관리자는 superadmin 신청을 승인할 수 없습니다.')
      }
      
      const targetDepartment = leaveData.department
      let hasPermission = false

      // 각 부서 매니저별 권한 체크
      if (userRoles.includes('개발팀_manager')) {
        hasPermission = ['개발1팀', '개발2팀'].includes(targetDepartment)
      } else if (userRoles.includes('개발3팀_manager')) {
        hasPermission = targetDepartment === '개발3팀'
      } else if (userRoles.includes('CAD_manager')) {
        hasPermission = targetDepartment === 'CAD'
      } else if (userRoles.includes('연구소_manager')) {
        hasPermission = targetDepartment === '연구소'
      } else if (userRoles.includes('경영팀_manager')) {
        hasPermission = targetDepartment === '경영팀'
      } else if (userRoles.includes('기획팀_manager')) {
        hasPermission = targetDepartment === '기획팀'
      } else if (userRoles.includes('영업팀_manager')) {
        hasPermission = targetDepartment === '영업팀'
      }

      if (!hasPermission) {
        throw new Error('해당 부서의 승인 권한이 없습니다.')
      }
      
    }

    // 승인자/반려자 이름 가져오기
    const { data: approverData } = await supabase
      .from('employees')
      .select('name')
      .eq('email', userEmail)
      .single()
    
    const approverName = approverData?.name || userEmail.split('@')[0]
    
    // Service role로 leave 상태 업데이트 (RLS 우회) - status와 승인자 정보 업데이트
    const updateData: any = { status: status }
    
    if (status === 'approved') {
      updateData.approved_by = approverName
      updateData.approved_at = new Date().toISOString()
    } else if (status === 'rejected') {
      updateData.rejected_by = approverName
      updateData.rejected_at = new Date().toISOString()
    }
    
    const { data: updateResult, error: updateError } = await supabase
      .from('leave')
      .update(updateData)
      .eq('id', id)
      .select()

    if (updateError) {
      console.error('Leave 업데이트 실패:', updateError)
      throw updateError
    }


    // 오전반차 승인 시 attendance_records 상태 업데이트
    if (status === 'approved' && leaveData.type === 'half_am') {
      try {
        const kstNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Seoul' }))
        const startDate = leaveData.start_date
        const endDate = leaveData.end_date

        // 해당 기간의 attendance_records 조회
        const { data: attendanceRecords, error: attError } = await supabase
          .from('attendance_records')
          .select('id, date, clock_in, status')
          .eq('user_email', leaveData.user_email)
          .gte('date', startDate)
          .lte('date', endDate)

        if (!attError && attendanceRecords) {
          for (const record of attendanceRecords) {
            const clockIn = record.clock_in
            let newStatus: string

            if (clockIn == null) {
              // 아직 출근 안 함 → 오전반차
              newStatus = '오전반차'
            } else {
              // 출근했으면 13:30 기준으로 지각/정상 재판정
              const [h, m] = clockIn.split(':').map(Number)
              const isLate = h > 13 || (h === 13 && m > 30)
              newStatus = isLate ? '지각' : '정상 출근'
            }

            // 기존 상태와 다를 때만 업데이트
            if (record.status !== newStatus) {
              await supabase
                .from('attendance_records')
                .update({ status: newStatus, updated_at: new Date().toISOString() })
                .eq('id', record.id)
            }
          }
        }
      } catch (attUpdateErr) {
        console.warn('오전반차 attendance_records 업데이트 실패 (승인은 정상 처리됨):', attUpdateErr)
      }
    }

    // 신청자에게 승인/반려 결과 알림은 이제 DB 트리거에서 자동으로 처리됨
    // leave_status_change_notification_trigger가 상태 변경 시 알림 발송

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