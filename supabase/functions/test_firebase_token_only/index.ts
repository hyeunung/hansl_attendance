import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { create } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

async function getFirebaseAccessToken() {
  try {
    console.log('🔑 [DEBUG] Firebase 접근 토큰 요청 시작');
    
    // 환경변수에서 가져오기
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not found in environment variables');
    }
    
    const serviceAccount = JSON.parse(serviceAccountJson);
    console.log(`📋 [DEBUG] 서비스 계정 로드 완료: ${serviceAccount.client_email}`);
    
    // JWT 헤더와 페이로드 생성
    const header = {
      alg: 'RS256',
      typ: 'JWT'
    };
    
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    };
    
    console.log('📋 [DEBUG] JWT Payload:', JSON.stringify(payload, null, 2));
    
    // Private Key 처리
    let privateKeyPem = serviceAccount.private_key;
    
    // 이스케이프된 newline 처리
    if (privateKeyPem.includes('\\n') && !privateKeyPem.includes('\n')) {
      console.log('🔄 [DEBUG] Converting escaped newlines');
      privateKeyPem = privateKeyPem.replace(/\\n/g, '\n');
    }
    
    // PEM 형식에서 base64 부분만 추출
    const pemContents = privateKeyPem
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\s/g, '');
    
    // base64를 ArrayBuffer로 변환
    const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));
    
    // crypto.subtle.importKey 사용
    console.log('🔑 [DEBUG] Private Key import 시작');
    const key = await crypto.subtle.importKey(
      'pkcs8',
      binaryDer,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256'
      },
      false,
      ['sign']
    );
    console.log('✅ [DEBUG] Private Key import 성공');
    
    // JWT 생성
    console.log('🔐 [DEBUG] JWT 생성 시작');
    const jwt = await create(header, payload, key);
    console.log('✅ [DEBUG] JWT 생성 완료');
    console.log(`   JWT 길이: ${jwt.length}`);
    console.log(`   JWT 첫 50자: ${jwt.substring(0, 50)}...`);
    
    // Google OAuth2 토큰 요청
    console.log('🌐 [DEBUG] Google OAuth2 토큰 요청 시작');
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
      })
    });
    
    console.log(`🔍 [DEBUG] OAuth2 응답 상태: ${tokenResponse.status}`);
    
    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      console.error('❌ [ERROR] OAuth2 토큰 요청 실패:', errorText);
      throw new Error(`Failed to get access token: ${tokenResponse.status} - ${errorText}`);
    }
    
    const tokenData = await tokenResponse.json();
    console.log('✅ [DEBUG] OAuth2 토큰 획득 성공');
    console.log(`   Access Token 존재: ${!!tokenData.access_token}`);
    console.log(`   Access Token 길이: ${tokenData.access_token ? tokenData.access_token.length : 0}`);
    console.log(`   만료 시간: ${tokenData.expires_in}초`);
    
    return {
      accessToken: tokenData.access_token,
      projectId: serviceAccount.project_id
    };
  } catch (error) {
    console.error('❌ [ERROR] Firebase 접근 토큰 획득 실패:', error);
    throw error;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    console.log('🔍 [DEBUG] Firebase 토큰 획득 테스트 시작');
    
    const result = await getFirebaseAccessToken();
    
    return new Response(JSON.stringify({
      success: true,
      message: 'Firebase 토큰 획득 성공',
      accessToken: result.accessToken ? '존재함' : '없음',
      accessTokenLength: result.accessToken ? result.accessToken.length : 0,
      projectId: result.projectId
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
    
  } catch (error) {
    console.error('❌ [ERROR] Firebase 토큰 획득 테스트 실패:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});


