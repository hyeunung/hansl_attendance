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
    const result = {
      step: 'start',
      firebase_env_exists: false,
      service_account: null,
      jwt_created: false,
      oauth_success: false,
      fcm_success: false,
      errors: []
    };

    // 1. 환경변수 확인
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    result.firebase_env_exists = !!serviceAccountJson;
    
    if (!serviceAccountJson) {
      result.errors.push('FIREBASE_SERVICE_ACCOUNT_JSON not found in environment');
      return new Response(JSON.stringify(result, null, 2), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      });
    }

    // 2. JSON 파싱
    try {
      const serviceAccount = JSON.parse(serviceAccountJson);
      result.service_account = {
        project_id: serviceAccount.project_id,
        client_email: serviceAccount.client_email,
        private_key_exists: !!serviceAccount.private_key,
        private_key_length: serviceAccount.private_key ? serviceAccount.private_key.length : 0
      };
    } catch (e) {
      result.errors.push(`JSON parse error: ${e.message}`);
      return new Response(JSON.stringify(result, null, 2), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      });
    }

    // 3. 실제 FCM 토큰 가져오기 (test@hansl.com)
    const KNOWN_FCM_TOKEN = "f23Fx1dZaO1oUYCZezD4CS:APA91bHAlsqXxvjvK3zw9pkZTYipSPRwW9DcZBnrrX8LuZ545AlRnPFQ_8Qx0lIXQpKKh5cUiIMavaUKT2Trw60iOtGlZzNv36b3kyMk5oBf2DIgXxB5bPc";
    
    result.fcm_token_info = {
      token_exists: true,
      token_length: KNOWN_FCM_TOKEN.length,
      token_prefix: KNOWN_FCM_TOKEN.substring(0, 20)
    };

    // 4. OAuth2 토큰 얻기 (Google API 사용)
    try {
      // JWT 생성을 위한 간단한 방법
      const serviceAccount = JSON.parse(serviceAccountJson);
      
      // Google에서 제공하는 서비스 계정 토큰 엔드포인트 직접 사용
      const tokenUrl = `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${serviceAccount.client_email}:generateAccessToken`;
      
      // 더 간단한 방법: Firebase Admin SDK가 사용하는 방식을 모방
      const jwtHeader = {
        alg: 'RS256',
        typ: 'JWT'
      };
      
      const now = Math.floor(Date.now() / 1000);
      const jwtPayload = {
        iss: serviceAccount.client_email,
        sub: serviceAccount.client_email,
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
        scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging'
      };
      
      result.jwt_info = {
        header: jwtHeader,
        payload: jwtPayload
      };
      
      // Private Key 처리
      let privateKey = serviceAccount.private_key;
      
      // 이스케이프된 newline 처리
      if (privateKey.includes('\\n')) {
        privateKey = privateKey.replace(/\\n/g, '\n');
      }
      
      // PEM 헤더/푸터 제거
      const pemContent = privateKey
        .replace(/-----BEGIN PRIVATE KEY-----/g, '')
        .replace(/-----END PRIVATE KEY-----/g, '')
        .replace(/\s/g, '');
      
      // Base64 디코딩
      const binaryDer = Uint8Array.from(atob(pemContent), c => c.charCodeAt(0));
      
      // Crypto Key Import
      const cryptoKey = await crypto.subtle.importKey(
        'pkcs8',
        binaryDer,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
      );
      
      // JWT 생성
      const encoder = new TextEncoder();
      const headerB64 = btoa(JSON.stringify(jwtHeader))
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
      const payloadB64 = btoa(JSON.stringify(jwtPayload))
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
      
      const dataToSign = `${headerB64}.${payloadB64}`;
      
      const signature = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        cryptoKey,
        encoder.encode(dataToSign)
      );
      
      const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
      
      const jwt = `${dataToSign}.${signatureB64}`;
      result.jwt_created = true;
      result.jwt_length = jwt.length;
      
      // OAuth2 토큰 요청
      const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion: jwt
        })
      });
      
      const tokenData = await tokenResponse.text();
      
      if (!tokenResponse.ok) {
        result.oauth_error = {
          status: tokenResponse.status,
          error: tokenData
        };
      } else {
        result.oauth_success = true;
        const parsedToken = JSON.parse(tokenData);
        result.oauth_info = {
          has_access_token: !!parsedToken.access_token,
          token_type: parsedToken.token_type,
          expires_in: parsedToken.expires_in
        };
        
        // FCM 테스트
        if (parsedToken.access_token) {
          const fcmMessage = {
            message: {
              token: KNOWN_FCM_TOKEN,
              notification: {
                title: '🔍 Debug Test',
                body: `Test at ${new Date().toISOString()}`
              }
            }
          };
          
          const fcmResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${parsedToken.access_token}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(fcmMessage)
            }
          );
          
          const fcmResult = await fcmResponse.text();
          
          result.fcm_response = {
            status: fcmResponse.status,
            ok: fcmResponse.ok,
            result: fcmResponse.ok ? JSON.parse(fcmResult) : fcmResult
          };
          
          result.fcm_success = fcmResponse.ok;
        }
      }
      
    } catch (e) {
      result.errors.push(`Processing error: ${e.message}`);
      result.error_stack = e.stack;
    }
    
    return new Response(JSON.stringify(result, null, 2), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });
    
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack
    }, null, 2), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });
  }
});