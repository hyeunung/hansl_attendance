#!/usr/bin/env node

// 2025년 1월 25일 시간으로 FCM 테스트
const crypto = require('crypto');
const https = require('https');
const fs = require('fs');

// Firebase 서비스 계정 로드
const serviceAccount = JSON.parse(
  fs.readFileSync('/Users/scott/workspace/hansl/hansl-attendance-firebase-adminsdk.json', 'utf8')
);

// 현재 시간 사용
const CORRECT_TIME = new Date();
const iat = Math.floor(CORRECT_TIME.getTime() / 1000);
const exp = iat + 3600;

console.log('📅 사용할 시간:', CORRECT_TIME.toISOString());
console.log('iat:', iat, '=', new Date(iat * 1000).toISOString());
console.log('exp:', exp, '=', new Date(exp * 1000).toISOString());

// JWT 헤더와 페이로드
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

// Base64URL 인코딩 함수
function base64url(str) {
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

// JWT 생성
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

console.log('\n🔑 JWT 생성 완료 (길이:', jwt.length + ')');

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
    console.log('\n📡 OAuth2 응답 (상태 코드:', res.statusCode + ')');
    
    if (res.statusCode === 200) {
      const tokenData = JSON.parse(data);
      console.log('✅ Access Token 획득 성공!');
      console.log('Token Type:', tokenData.token_type);
      console.log('Expires In:', tokenData.expires_in, 'seconds');
      
      // FCM 메시지 전송
      sendFCMMessage(tokenData.access_token);
    } else {
      console.log('❌ OAuth2 실패:', data);
    }
  });
});

tokenReq.on('error', (e) => {
  console.error('❌ 요청 에러:', e.message);
});

tokenReq.write(tokenRequestData);
tokenReq.end();

function sendFCMMessage(accessToken) {
  const fcmToken = "f23Fx1dZaO1oUYCZezD4CS:APA91bHAlsqXxvjvK3zw9pkZTYipSPRwW9DcZBnrrX8LuZ545AlRnPFQ_8Qx0lIXQpKKh5cUiIMavaUKT2Trw60iOtGlZzNv36b3kyMk5oBf2DIgXxB5bPc";
  
  const message = {
    message: {
      token: fcmToken,
      notification: {
        title: '🎉 FCM 테스트 성공!',
        body: '새로운 Firebase 키로 푸시 알림 전송 성공!'
      }
    }
  };
  
  const messageData = JSON.stringify(message);
  
  const fcmOptions = {
    hostname: 'fcm.googleapis.com',
    path: `/v1/projects/${serviceAccount.project_id}/messages:send`,
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Content-Length': messageData.length
    }
  };
  
  console.log('\n📤 FCM 메시지 전송 중...');
  
  const fcmReq = https.request(fcmOptions, (res) => {
    let data = '';
    
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('FCM 응답 (상태 코드:', res.statusCode + ')');
      
      if (res.statusCode === 200) {
        console.log('✅ 푸시 알림 전송 성공!');
        console.log('응답:', JSON.parse(data));
      } else {
        console.log('❌ FCM 전송 실패:', data);
      }
    });
  });
  
  fcmReq.on('error', (e) => {
    console.error('❌ FCM 요청 에러:', e.message);
  });
  
  fcmReq.write(messageData);
  fcmReq.end();
}