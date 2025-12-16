const { GoogleAuth } = require('google-auth-library');
const https = require('https');
const fs = require('fs');

async function testFCMSending() {
    try {
        // Firebase 서비스 계정 키 로드
        const keyFile = './hansl-attendance-firebase-adminsdk.json';
        if (\!fs.existsSync(keyFile)) {
            console.log('❌ Firebase 키 파일 없음:', keyFile);
            return;
        }
        
        console.log('✅ Firebase 키 파일 발견');
        
        // Google Auth 초기화
        const auth = new GoogleAuth({
            keyFile: keyFile,
            scopes: ['https://www.googleapis.com/auth/firebase.messaging']
        });
        
        // Access Token 생성
        const accessToken = await auth.getAccessToken();
        console.log('✅ FCM Access Token 생성 성공');
        console.log('Token:', accessToken.substring(0, 50) + '...');
        
        // FCM 프로젝트 ID 확인
        const serviceAccount = JSON.parse(fs.readFileSync(keyFile, 'utf8'));
        console.log('✅ 프로젝트 ID:', serviceAccount.project_id);
        
        return true;
        
    } catch (error) {
        console.log('❌ FCM 인증 실패:', error.message);
        if (error.message.includes('JWT signature')) {
            console.log('🚨 Private Key 손상 가능성\!');
            console.log('→ Firebase Console에서 새 키 생성 필요');
        }
        return false;
    }
}

testFCMSending();
