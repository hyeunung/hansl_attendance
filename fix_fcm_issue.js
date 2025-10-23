#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function generateNewFCMToken() {
  const targetEmail = 'hyun-woong.jeong@hansl.com';
  
  console.log('🔧 FCM 토큰 문제 해결');
  console.log('===================');
  console.log(`📧 대상: ${targetEmail}`);
  console.log('');

  console.log('🚨 문제 진단 결과:');
  console.log('1. ✅ 사용자 권한: app_admin, middle_manager, lead buyer, superadmin');
  console.log('2. ✅ FCM 토큰: 존재함 (142자)');
  console.log('3. ✅ 알림 기록: 최근까지 정상 수신');
  console.log('4. ❌ FCM 전송: 실패 (BadEnvironmentKeyInToken)');
  console.log('');

  console.log('🔍 원인 분석:');
  console.log('- Firebase APNs 인증서 환경 불일치 (Development/Production)');
  console.log('- FCM 토큰이 test@hansl.com과 동일함 (중복 사용)');
  console.log('- iOS 기기의 APNs 환경과 Firebase 설정 불일치');
  console.log('');

  console.log('📋 해결 방법:');
  console.log('');
  
  console.log('🔧 방법 1: Firebase Console APNs 설정 확인');
  console.log('1. Firebase Console 접속:');
  console.log('   https://console.firebase.google.com/project/hansl-attendance/settings/cloudmessaging');
  console.log('2. iOS 앱 → APNs 인증서 확인');
  console.log('3. Development/Production 환경 일치 확인');
  console.log('');

  console.log('🔧 방법 2: 새로운 FCM 토큰 생성');
  console.log('1. hyun-woong.jeong@hansl.com으로 앱 완전 로그아웃');
  console.log('2. 앱 삭제 후 재설치');
  console.log('3. 다시 로그인하여 새 FCM 토큰 생성');
  console.log('4. 푸시 알림 권한 재허용');
  console.log('');

  console.log('🔧 방법 3: 테스트용 임시 토큰 제거');
  console.log('현재 test@hansl.com과 동일한 토큰 사용 중');
  
  // FCM 토큰 초기화
  try {
    const { error } = await supabase
      .from('employees')
      .update({ fcm_token: null })
      .eq('email', targetEmail);

    if (error) {
      console.log('❌ FCM 토큰 초기화 실패:', error.message);
    } else {
      console.log('✅ FCM 토큰 초기화 완료 - 앱에서 다시 로그인하세요');
    }
  } catch (err) {
    console.log('❌ 오류:', err.message);
  }

  console.log('');
  console.log('🧪 테스트 절차:');
  console.log('1. 앱 재설치 → 로그인 → 새 토큰 생성');
  console.log('2. node check_user_fcm.js 실행하여 새 토큰 확인');
  console.log('3. 실제 발주 요청 생성하여 알림 테스트');
  console.log('4. Firebase Console에서 직접 테스트 메시지 전송');
  console.log('');

  console.log('⚡ 즉시 확인 가능한 방법:');
  console.log('Firebase Console → Cloud Messaging → Send test message');
  console.log('새 FCM 토큰으로 직접 테스트 메시지 전송해보기');
}

generateNewFCMToken();