const admin = require('firebase-admin');
const serviceAccount = require('./hansl-attendance-firebase-adminsdk.json');

// Firebase Admin SDK 초기화
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'hansl-attendance'
});

async function sendTestNotification() {
  const fcmToken = "f23Fx1dZaO1oUYCZezD4CS:APA91bHAlsqXxvjvK3zw9pkZTYipSPRwW9DcZBnrrX8LuZ545AlRnPFQ_8Qx0lIXQpKKh5cUiIMavaUKT2Trw60iOtGlZzNv36b3kyMk5oBf2DIgXxB5bPc";
  
  const message = {
    notification: {
      title: '🎉 Node.js Firebase Admin 테스트',
      body: `테스트 시간: ${new Date().toLocaleTimeString('ko-KR')}`
    },
    data: {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      sound: 'default'
    },
    token: fcmToken
  };

  try {
    console.log('📤 FCM 메시지 전송 중...');
    const response = await admin.messaging().send(message);
    console.log('✅ 성공적으로 전송됨:', response);
  } catch (error) {
    console.error('❌ 전송 실패:', error);
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log('⚠️  FCM 토큰이 유효하지 않습니다. 앱을 재설치하거나 다시 로그인해야 합니다.');
    }
  }
}

sendTestNotification();