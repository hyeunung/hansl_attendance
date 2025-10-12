import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // 1. 환경변수에서 Firebase 키 가져오기
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not found');
    }
    
    const serviceAccount = JSON.parse(serviceAccountJson);
    
    // 2. 가장 단순한 JWT 생성
    const header = btoa(JSON.stringify({
      alg: 'RS256',
      typ: 'JWT'
    })).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    
    const now = Math.floor(Date.now() / 1000);
    const payload = btoa(JSON.stringify({
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      iat: now,
      exp: now + 3600
    })).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    
    const signatureInput = `${header}.${payload}`;
    
    // 3. Private key로 서명
    let privateKey = serviceAccount.private_key;
    if (privateKey.includes('\\n')) {
      privateKey = privateKey.replace(/\\n/g, '\n');
    }
    
    const pemContents = privateKey
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\s/g, '');
    
    const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));
    
    const key = await crypto.subtle.importKey(
      'pkcs8',
      binaryDer,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign']
    );
    
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(signatureInput)
    );
    
    const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    
    const jwt = `${signatureInput}.${sig}`;
    
    // 4. Google OAuth2 토큰 요청
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
      })
    });
    
    const tokenResult = await tokenResponse.text();
    
    if (!tokenResponse.ok) {
      return new Response(JSON.stringify({
        success: false,
        error: 'OAuth failed',
        details: tokenResult
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      });
    }
    
    const { access_token } = JSON.parse(tokenResult);
    
    // 5. 하드코딩된 FCM 토큰으로 테스트
    const testFcmToken = "f23Fx1dZaO1oUYCZezD4CS:APA91bHAlsqXxvjvK3zw9pkZTYipSPRwW9DcZBnrrX8LuZ545AlRnPFQ_8Qx0lIXQpKKh5cUiIMavaUKT2Trw60iOtGlZzNv36b3kyMk5oBf2DIgXxB5bPc"; // test@hansl.com의 FCM 토큰
    
    const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/hansl-attendance/messages:send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${access_token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message: {
          token: testFcmToken,
          notification: {
            title: '🎉 단순 테스트',
            body: '완전히 새로운 코드로 테스트'
          },
          data: {
            type: 'test',
            timestamp: new Date().toISOString()
          }
        }
      })
    });
    
    const fcmResult = await fcmResponse.text();
    
    return new Response(JSON.stringify({
      success: fcmResponse.ok,
      oauth: tokenResponse.ok ? 'success' : 'failed',
      fcm: fcmResponse.ok ? 'success' : 'failed',
      fcmStatus: fcmResponse.status,
      result: fcmResponse.ok ? JSON.parse(fcmResult) : fcmResult
    }, null, 2), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });
    
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });
  }
});