// Firebase Admin SDK를 사용한 직접 FCM 테스트
const admin = require('firebase-admin');
require('dotenv').config();

// 서비스 계정 키 필요 (Firebase Console에서 다운로드)
// 이 파일을 service-account.json으로 저장하고 테스트
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'hansl-attendance'
});

async function testDirectFCM() {
  try {
    // 테스트할 FCM 토큰 (실제 토큰으로 교체 필요)
    const testToken = 'ccf6diQD8EquoOF6od7ycE:APA91bHLcJ2nPhbkrGj2W0MFE_4bXnjFzHZGHzFfp-E_MbnKEtql7JYysX_pM4kSYkGI1Dh42NYJpau19GM8wNb_H8kzbQOYruY4XFxsyLcpurz2QqeMJgs';
    
    const message = {
      notification: {
        title: '🧪 Firebase Admin SDK 테스트',
        body: '직접 Firebase Admin SDK를 사용한 테스트입니다.'
      },
      data: {
        type: 'test',
        timestamp: new Date().toISOString()
      },
      token: testToken,
      android: {
        priority: 'high',
        notification: {
          sound: 'default'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'content-available': 1
          }
        }
      }
    };
    
    console.log('📤 FCM 메시지 전송 중...');
    console.log('   토큰:', testToken.substring(0, 30) + '...');
    
    const response = await admin.messaging().send(message);
    console.log('✅ 성공적으로 전송됨:', response);
    
  } catch (error) {
    console.error('❌ 전송 실패:', error);
    
    if (error.code) {
      console.error('   에러 코드:', error.code);
      console.error('   에러 메시지:', error.message);
      
      // 일반적인 FCM 오류 해석
      switch(error.code) {
        case 'messaging/invalid-registration-token':
        case 'messaging/registration-token-not-registered':
          console.error('   → 토큰이 유효하지 않거나 만료되었습니다. 앱을 다시 실행하여 새 토큰을 받아야 합니다.');
          break;
        case 'messaging/invalid-argument':
          console.error('   → 메시지 형식이 잘못되었습니다.');
          break;
        case 'messaging/authentication-error':
          console.error('   → 서비스 계정 인증 실패. 서비스 계정 키를 확인하세요.');
          break;
        case 'messaging/server-unavailable':
          console.error('   → FCM 서버에 연결할 수 없습니다.');
          break;
        default:
          console.error('   → 알 수 없는 오류입니다.');
      }
    }
  }
  
  process.exit(0);
}

// 서비스 계정 파일이 있는지 확인
const fs = require('fs');
if (!fs.existsSync('./service-account.json')) {
  console.error('❌ service-account.json 파일이 없습니다.');
  console.error('   Firebase Console → 프로젝트 설정 → 서비스 계정에서');
  console.error('   새 비공개 키를 생성하여 service-account.json으로 저장하세요.');
  process.exit(1);
}

testDirectFCM();