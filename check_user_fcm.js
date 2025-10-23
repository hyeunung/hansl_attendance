#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Supabase 환경변수가 설정되지 않았습니다.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkUserFCMStatus() {
  const targetEmail = 'hyun-woong.jeong@hansl.com';
  
  console.log('🔍 사용자 FCM 상태 확인');
  console.log('=====================');
  console.log(`📧 대상 계정: ${targetEmail}`);
  console.log(`📅 확인 시간: ${new Date().toISOString()}`);
  console.log('');

  try {
    // 1. 사용자 기본 정보 조회
    console.log('1️⃣ 사용자 기본 정보 조회');
    const { data: employee, error: employeeError } = await supabase
      .from('employees')
      .select('*')
      .eq('email', targetEmail)
      .single();

    if (employeeError) {
      console.error('❌ 사용자 조회 실패:', employeeError.message);
      return;
    }

    if (!employee) {
      console.error('❌ 사용자를 찾을 수 없습니다.');
      return;
    }

    console.log(`✅ 사용자 정보:`);
    console.log(`   이름: ${employee.name}`);
    console.log(`   이메일: ${employee.email}`);
    console.log(`   부서: ${employee.department || '미설정'}`);
    console.log(`   purchase_role: ${JSON.stringify(employee.purchase_role)}`);
    console.log(`   attendance_role: ${JSON.stringify(employee.attendance_role)}`);
    console.log(`   FCM 토큰: ${employee.fcm_token ? '있음 ✅' : '없음 ❌'}`);
    
    if (employee.fcm_token) {
      console.log(`   FCM 토큰 길이: ${employee.fcm_token.length}`);
      console.log(`   FCM 토큰 (일부): ${employee.fcm_token.substring(0, 30)}...`);
    }
    console.log('');

    // 2. 권한별 알림 수신 자격 확인
    console.log('2️⃣ 알림 수신 자격 확인');
    
    // purchase_role 확인
    const purchaseRoles = employee.purchase_role || [];
    const hasAppAdmin = purchaseRoles.includes('app_admin');
    const hasMiddleManager = purchaseRoles.includes('middle_manager');
    const hasLeadBuyer = purchaseRoles.includes('lead buyer');
    const hasFinalApprover = purchaseRoles.includes('final_approver') || 
                           purchaseRoles.includes('raw_material_manager') || 
                           purchaseRoles.includes('consumable_manager');

    console.log(`📦 구매 관련 알림 수신 자격:`);
    console.log(`   - 신규 구매요청: ${hasAppAdmin || hasMiddleManager ? '✅' : '❌'}`);
    console.log(`   - 1차 승인 완료: ${hasAppAdmin || hasFinalApprover ? '✅' : '❌'}`);
    console.log(`   - 구매대기 알림: ${hasLeadBuyer ? '✅' : '❌'}`);
    console.log(`   - app_admin 전체권한: ${hasAppAdmin ? '✅' : '❌'}`);
    console.log('');

    // attendance_role 확인  
    const attendanceRoles = employee.attendance_role || [];
    const hasSuperAdmin = attendanceRoles.includes('superadmin');
    const hasAdmin = attendanceRoles.includes('admin');
    const hasDeptManager = attendanceRoles.some(role => role.endsWith('_manager'));

    console.log(`👥 연차/출장 관련 알림 수신 자격:`);
    console.log(`   - superadmin: ${hasSuperAdmin ? '✅' : '❌'}`);
    console.log(`   - admin: ${hasAdmin ? '✅ (제외됨)' : '❌'}`);
    console.log(`   - 부서 매니저: ${hasDeptManager ? '✅' : '❌'}`);
    console.log('');

    // 3. 최근 알림 기록 확인
    console.log('3️⃣ 최근 알림 기록 확인');
    const { data: notifications, error: notifError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_email', targetEmail)
      .order('created_at', { ascending: false })
      .limit(5);

    if (notifError) {
      console.error('❌ 알림 기록 조회 실패:', notifError.message);
    } else {
      console.log(`📋 최근 알림 ${notifications.length}개:`);
      notifications.forEach((notif, index) => {
        console.log(`   ${index + 1}. ${notif.title} (${new Date(notif.created_at).toLocaleString()})`);
        console.log(`      읽음: ${notif.is_read ? '✅' : '❌'}, 타입: ${notif.type}`);
      });
    }
    console.log('');

    // 4. FCM 토큰 테스트 (있는 경우)
    if (employee.fcm_token) {
      console.log('4️⃣ FCM 토큰 테스트');
      await testFCMToken(employee.fcm_token, employee.email);
    } else {
      console.log('4️⃣ FCM 토큰 없음 - 앱에서 다시 로그인 필요');
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  }
}

async function testFCMToken(fcmToken, email) {
  try {
    const response = await supabase.functions.invoke('send_fcm_notification', {
      body: {
        type: 'custom',
        title: '🧪 FCM 테스트',
        body: `${email} 계정 FCM 토큰 테스트입니다.`,
        fcm_tokens: [fcmToken],
        skip_db_notification: true
      }
    });

    if (response.error) {
      console.log('❌ FCM 테스트 실패:', response.error.message);
    } else {
      console.log('✅ FCM 테스트 요청 전송 완료');
      console.log('   결과:', JSON.stringify(response.data, null, 2));
    }
  } catch (error) {
    console.log('❌ FCM 테스트 오류:', error.message);
  }
}

checkUserFCMStatus();