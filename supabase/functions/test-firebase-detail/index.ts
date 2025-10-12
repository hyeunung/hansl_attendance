import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { create } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const debugInfo = {
    step: 'start',
    details: {}
  };

  try {
    // 1. 환경변수 확인
    debugInfo.step = 'env_check';
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({
        success: false,
        error: 'FIREBASE_SERVICE_ACCOUNT_JSON not found',
        debug: debugInfo
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      });
    }

    debugInfo.details.jsonLength = serviceAccountJson.length;
    debugInfo.details.jsonStart = serviceAccountJson.substring(0, 50);

    // 2. JSON 파싱
    debugInfo.step = 'json_parse';
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
      debugInfo.details.projectId = serviceAccount.project_id;
      debugInfo.details.clientEmail = serviceAccount.client_email;
      debugInfo.details.hasPrivateKey = !!serviceAccount.private_key;
      debugInfo.details.privateKeyLength = serviceAccount.private_key?.length;
      
      // Private key 형식 확인
      const pk = serviceAccount.private_key;
      debugInfo.details.pkStartsWith = pk?.substring(0, 30);
      debugInfo.details.pkEndsWith = pk?.substring(pk.length - 30);
      debugInfo.details.hasNewlines = pk?.includes('\n');
      debugInfo.details.hasEscapedNewlines = pk?.includes('\\n');
      
    } catch (e) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to parse service account JSON',
        details: e.message,
        debug: debugInfo
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      });
    }

    // 3. Private Key 처리 테스트
    debugInfo.step = 'private_key_processing';
    
    // 여러 방법으로 처리해보기
    const originalKey = serviceAccount.private_key;
    
    // 방법 1: 기존 코드
    const method1 = originalKey.replace(/\\n/g, '\n');
    
    // 방법 2: 이미 줄바꿈이 있는 경우
    const method2 = originalKey;
    
    // 방법 3: 이중 이스케이프 처리
    const method3 = originalKey.replace(/\\\\n/g, '\n');
    
    debugInfo.details.method1Length = method1.length;
    debugInfo.details.method1HasRealNewlines = method1.includes('\n') && !method1.includes('\\n');
    debugInfo.details.method2Length = method2.length;
    debugInfo.details.method2HasRealNewlines = method2.includes('\n') && !method2.includes('\\n');
    debugInfo.details.method3Length = method3.length;
    debugInfo.details.method3HasRealNewlines = method3.includes('\n') && !method3.includes('\\n');

    // 실제로 사용할 키 선택
    let privateKeyPem = method1; // 기본값
    
    if (originalKey.includes('\\n') && !originalKey.includes('\n')) {
      // 이스케이프된 줄바꿈만 있는 경우
      privateKeyPem = originalKey.replace(/\\n/g, '\n');
      debugInfo.details.keyProcessMethod = 'escaped_newlines';
    } else if (originalKey.includes('\n') && !originalKey.includes('\\n')) {
      // 실제 줄바꿈만 있는 경우
      privateKeyPem = originalKey;
      debugInfo.details.keyProcessMethod = 'real_newlines';
    } else {
      // 혼재하거나 불확실한 경우
      privateKeyPem = originalKey.replace(/\\n/g, '\n');
      debugInfo.details.keyProcessMethod = 'default_replace';
    }

    // 4. JWT 생성
    debugInfo.step = 'jwt_creation';
    const header = { alg: 'RS256', typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    };

    let jwt;
    try {
      const pemContents = privateKeyPem
        .replace('-----BEGIN PRIVATE KEY-----', '')
        .replace('-----END PRIVATE KEY-----', '')
        .replace(/\s/g, '');
      
      debugInfo.details.pemContentsLength = pemContents.length;
      
      const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));
      debugInfo.details.binaryDerLength = binaryDer.length;
      
      const key = await crypto.subtle.importKey(
        'pkcs8',
        binaryDer,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
      );

      jwt = await create(header, payload, key);
      debugInfo.details.jwtLength = jwt.length;
      debugInfo.details.jwtStart = jwt.substring(0, 50);
      
    } catch (e) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to create JWT',
        details: e.message,
        stack: e.stack,
        debug: debugInfo
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      });
    }

    // 5. OAuth2 토큰 요청
    debugInfo.step = 'oauth2_request';
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
      })
    });

    const responseText = await tokenResponse.text();
    debugInfo.details.oauth2Status = tokenResponse.status;
    
    if (!tokenResponse.ok) {
      return new Response(JSON.stringify({
        success: false,
        error: 'OAuth2 failed',
        status: tokenResponse.status,
        response: responseText,
        debug: debugInfo
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      });
    }

    const tokenData = JSON.parse(responseText);

    return new Response(JSON.stringify({
      success: true,
      message: 'Firebase auth successful',
      projectId: serviceAccount.project_id,
      hasToken: !!tokenData.access_token,
      expiresIn: tokenData.expires_in,
      debug: debugInfo
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack,
      debug: debugInfo
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    });
  }
});