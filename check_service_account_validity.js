#!/usr/bin/env node

const fs = require('fs');
const https = require('https');

// Firebase 서비스 계정 정보 확인
const serviceAccount = JSON.parse(
  fs.readFileSync('/Users/scott/workspace/hansl/hansl-attendance-firebase-adminsdk.json', 'utf8')
);

console.log('🔍 Firebase 서비스 계정 키 정보 확인');
console.log('=====================================\n');

console.log('📋 기본 정보:');
console.log('  • Project ID:', serviceAccount.project_id);
console.log('  • Client Email:', serviceAccount.client_email);
console.log('  • Private Key ID:', serviceAccount.private_key_id);
console.log('  • Client ID:', serviceAccount.client_id);

// 서비스 계정 생성 시기 추정 (private_key_id의 첫 8자리를 기반으로)
console.log('\n📅 키 정보:');
console.log('  • Private Key ID:', serviceAccount.private_key_id);
console.log('  • Key Type:', serviceAccount.type);

// Google API를 통한 서비스 계정 상태 확인
console.log('\n🔐 서비스 계정 유효성 테스트:');
console.log('  테스트 중...');

// 간단한 Google API 호출로 키 유효성 확인
const testUrl = `https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=test`;

// 서비스 계정 메타데이터 확인을 위한 API 호출
const options = {
  hostname: 'iam.googleapis.com',
  path: `/v1/projects/${serviceAccount.project_id}/serviceAccounts/${serviceAccount.client_email}`,
  method: 'GET',
  headers: {
    'Content-Type': 'application/json'
  }
};

// 메타데이터 서버를 통한 확인 (인증 없이)
const metadataReq = https.request(options, (res) => {
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    if (res.statusCode === 401 || res.statusCode === 403) {
      console.log('  ℹ️ 서비스 계정이 존재합니다 (인증 필요)');
    } else if (res.statusCode === 404) {
      console.log('  ❌ 서비스 계정을 찾을 수 없습니다!');
    } else {
      console.log('  상태 코드:', res.statusCode);
    }
  });
});

metadataReq.on('error', (e) => {
  console.log('  ⚠️ 네트워크 확인 불가:', e.message);
});

metadataReq.end();

// 키 만료 관련 정보
console.log('\n📌 Firebase 서비스 계정 키 만료 정책:');
console.log('  • 서비스 계정 자체: 만료 없음 (계속 사용 가능)');
console.log('  • 다운로드한 JSON 키: 만료 없음 (삭제하지 않는 한 계속 유효)');
console.log('  • 키가 무효화되는 경우:');
console.log('    - Firebase Console에서 수동으로 키 삭제');
console.log('    - 새 키 생성 시 기존 키를 비활성화한 경우');
console.log('    - 프로젝트 삭제 또는 서비스 계정 삭제');
console.log('    - Google Cloud Console에서 키 회전 정책 설정');

console.log('\n💡 현재 JWT 서명 실패 원인 가능성:');
console.log('  1. Private Key 형식 문제 (이스케이프, 줄바꿈 등)');
console.log('  2. 서비스 계정 권한 부족');
console.log('  3. Firebase 프로젝트 설정 변경');
console.log('  4. 시간 동기화 문제 (하지만 현재 시간은 정상)');

// Private Key 형식 확인
console.log('\n🔑 Private Key 형식 검증:');
const privateKey = serviceAccount.private_key;
const hasBeginMarker = privateKey.includes('-----BEGIN PRIVATE KEY-----');
const hasEndMarker = privateKey.includes('-----END PRIVATE KEY-----');
const hasNewlines = privateKey.includes('\\n');
const hasActualNewlines = privateKey.includes('\n');

console.log('  • BEGIN 마커 존재:', hasBeginMarker ? '✅' : '❌');
console.log('  • END 마커 존재:', hasEndMarker ? '✅' : '❌');
console.log('  • 이스케이프된 줄바꿈 (\\\\n):', hasNewlines ? '있음' : '없음');
console.log('  • 실제 줄바꿈 (\\n):', hasActualNewlines ? '있음' : '없음');
console.log('  • Key 길이:', privateKey.length, 'characters');

// JWT 생성 테스트를 위한 추가 정보
console.log('\n🧪 JWT 생성 디버깅 정보:');
console.log('  • 현재 시간 (Unix):', Math.floor(Date.now() / 1000));
console.log('  • 현재 시간 (ISO):', new Date().toISOString());
console.log('  • 타임존:', Intl.DateTimeFormat().resolvedOptions().timeZone);