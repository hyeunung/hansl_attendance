// 시간 문제 확인 스크립트
const now = new Date();
console.log("현재 시스템 시간:", now.toISOString());
console.log("Unix timestamp:", Math.floor(now.getTime() / 1000));
console.log("로컬 시간:", now.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' }));

// Firebase 서비스 계정 생성일 확인
const serviceAccountCreated = new Date('2024-09-19'); // 9월 19일 생성
console.log("\nFirebase 서비스 계정 생성일:", serviceAccountCreated.toISOString());

// JWT의 iat와 exp 확인
const iat = Math.floor(now.getTime() / 1000);
const exp = iat + 3600;
console.log("\nJWT iat:", iat, "=", new Date(iat * 1000).toISOString());
console.log("JWT exp:", exp, "=", new Date(exp * 1000).toISOString());

// 시간 차이 확인
const timeDiff = now - serviceAccountCreated;
const daysDiff = Math.floor(timeDiff / (1000 * 60 * 60 * 24));
console.log("\n서비스 계정 생성 후 경과일:", daysDiff, "일");

if (now > new Date('2025-09-19')) {
  console.log("\n⚠️ 경고: 현재 시간이 미래(2025년 10월)로 설정되어 있습니다!");
  console.log("정상 시간은 2025년 1월이어야 합니다.");
}