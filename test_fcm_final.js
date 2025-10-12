#!/usr/bin/env node

const https = require('https');
const fs = require('fs');

// Firebase 서비스 계정 로드
const serviceAccount = JSON.parse(
  fs.readFileSync('/Users/scott/workspace/hansl/hansl-attendance-firebase-adminsdk.json', 'utf8')
);

// JWT 생성을 위한 crypto 모듈
const crypto = require('crypto');

async function getAccessToken() {
  return new Promise((resolve, reject) => {
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 3600;

    const header = {
      alg: 'RS256',
      typ: 'JWT'
    };

    const payload = {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: iat,
      exp: exp,
      scope: 'https://www.googleapis.com/auth/firebase.messaging'
    };

    // Base64URL 인코딩
    const base64url = (str) => {
      return Buffer.from(str)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
    };

    const headerB64 = base64url(JSON.stringify(header));
    const payloadB64 = base64url(JSON.stringify(payload));
    const dataToSign = `${headerB64}.${payloadB64}`;

    // 서명 생성
    const sign = crypto.createSign('RSA-SHA256');
    sign.update(dataToSign);
    const signature = sign.sign(serviceAccount.private_key, 'base64');
    const signatureB64 = signature
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');

    const jwt = `${dataToSign}.${signatureB64}`;

    // OAuth2 토큰 요청
    const tokenRequestData = `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`;

    const tokenOptions = {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': tokenRequestData.length
      }
    };

    const tokenReq = https.request(tokenOptions, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          const tokenData = JSON.parse(data);
          console.log('✅ Access Token 획득 성공!');
          resolve(tokenData.access_token);
        } else {
          console.log('❌ OAuth2 실패:', data);
          reject(new Error(data));
        }
      });
    });

    tokenReq.on('error', reject);
    tokenReq.write(tokenRequestData);
    tokenReq.end();
  });
}

async function sendFCMMessage(accessToken) {
  return new Promise((resolve, reject) => {
    // 정확한 FCM 토큰
    const fcmToken = "f23Fx1dZaO1oUYCZezD4CS:APA91bHAlsqXxvjvK3zw9pkZTYipSPRwW9DcZBnrrX8LuZ545AlRnPFQ_8Qx0lIXQpKKh5cUiIMavaUKT2Trw60iOtGlZzNv36b3kyMk5oBf2DIgXxB5bPc";
    
    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: "🎉 Firebase 키 교체 성공!",
          body: "새로운 Firebase 서비스 계정 키로 FCM 전송 성공!"
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          sound: "default"
        }
      }
    };
    
    const messageData = JSON.stringify(message);
    console.log('\n📤 전송할 메시지:', messageData);
    
    const fcmOptions = {
      hostname: 'fcm.googleapis.com',
      path: `/v1/projects/${serviceAccount.project_id}/messages:send`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(messageData)
      }
    };
    
    const fcmReq = https.request(fcmOptions, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        console.log('\n📡 FCM 응답 (상태 코드:', res.statusCode + ')');
        
        if (res.statusCode === 200) {
          console.log('✅ 푸시 알림 전송 성공!');
          const result = JSON.parse(data);
          console.log('Message ID:', result.name);
          resolve(result);
        } else {
          console.log('❌ FCM 전송 실패:');
          console.log(data);
          reject(new Error(data));
        }
      });
    });
    
    fcmReq.on('error', reject);
    fcmReq.write(messageData);
    fcmReq.end();
  });
}

// 메인 실행
async function main() {
  try {
    console.log('🚀 FCM 푸시 알림 테스트 시작');
    console.log('=====================================');
    console.log('📅 현재 시간:', new Date().toISOString());
    console.log('📌 Project ID:', serviceAccount.project_id);
    console.log('📧 Service Account:', serviceAccount.client_email);
    console.log('🔑 Private Key ID:', serviceAccount.private_key_id);
    console.log('\n1️⃣ Access Token 획득 중...');
    
    const accessToken = await getAccessToken();
    
    console.log('\n2️⃣ FCM 메시지 전송 중...');
    await sendFCMMessage(accessToken);
    
    console.log('\n✨ 테스트 완료!');
    console.log('test@hansl.com 계정의 기기에서 푸시 알림을 확인하세요.');
    
  } catch (error) {
    console.error('\n❌ 오류 발생:', error.message);
  }
}

main();