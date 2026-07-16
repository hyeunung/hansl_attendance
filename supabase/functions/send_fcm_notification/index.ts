// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.
// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { create } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
async function getFirebaseAccessToken() {
  try {
    console.log('🔑 [DEBUG] Firebase 접근 토큰 요청 시작');

    // 환경변수에서 가져오기 (원래대로 복원)
    console.log('🔍 [DEBUG] 환경변수 확인 시작');
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');

    console.log('🔍 [DEBUG] 환경변수 확인:');
    console.log(`   FIREBASE_SERVICE_ACCOUNT_JSON 존재: ${!!serviceAccountJson}`);
    console.log(`   길이: ${serviceAccountJson ? serviceAccountJson.length : 0}`);

    if (!serviceAccountJson) {
      console.error('❌ [ERROR] FIREBASE_SERVICE_ACCOUNT_JSON 환경변수가 없습니다');
      console.log('🔍 [DEBUG] 사용 가능한 환경변수들:');
      for (const [key, value] of Object.entries(Deno.env.toObject())) {
        if (key.includes('FIREBASE') || key.includes('SUPABASE')) {
          console.log(`   ${key}: ${value ? '설정됨 (길이: ' + value.length + ')' : '없음'}`);
        }
      }
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not found in environment variables');
    }

    console.log('✅ [DEBUG] 환경변수 존재 확인 완료');

    // JSON 파싱 단계
    console.log('🔍 [DEBUG] JSON 파싱 시작');
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
      console.log('✅ [DEBUG] JSON 파싱 성공');
    } catch (parseError) {
      console.error('❌ [ERROR] JSON 파싱 실패:', parseError);
      throw new Error(`Failed to parse service account JSON: ${parseError.message}`);
    }

    console.log(`📋 [DEBUG] 서비스 계정 로드 완료: ${serviceAccount.client_email}`);
    console.log(`   프로젝트 ID: ${serviceAccount.project_id}`);
    console.log(`   Private Key 존재: ${!!serviceAccount.private_key}`);
    console.log(`   Private Key 길이: ${serviceAccount.private_key ? serviceAccount.private_key.length : 0}`);
    // JWT 헤더와 페이로드 생성
    const header = {
      alg: 'RS256',
      typ: 'JWT'
    };
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    };

    console.log('📋 [DEBUG] JWT Payload:', JSON.stringify(payload, null, 2));

    // Private Key 처리
    console.log('🔍 [DEBUG] Private Key 처리 시작');
    let privateKeyPem = serviceAccount.private_key;

    console.log('🔍 [DEBUG] Private Key 분석:');
    console.log(`   원본 길이: ${privateKeyPem.length}`);
    console.log(`   이스케이프된 \\\\n 포함: ${privateKeyPem.includes('\\\\n')}`);
    console.log(`   실제 newline 포함: ${privateKeyPem.includes('\n')}`);
    console.log(`   시작 부분: ${privateKeyPem.substring(0, 30)}...`);

    // 이중 이스케이프된 newline 처리 (DB에서 가져온 경우)
    if (privateKeyPem.includes('\\\\\\\\n')) {
      console.log('🔄 [DEBUG] Converting double-escaped newlines');
      privateKeyPem = privateKeyPem.replace(/\\\\\\\\n/g, '\n');
      console.log(`   변환 후 길이: ${privateKeyPem.length}`);
    } else if (privateKeyPem.includes('\\\\n') && !privateKeyPem.includes('\n')) {
      console.log('🔄 [DEBUG] Converting single-escaped newlines');
      privateKeyPem = privateKeyPem.replace(/\\\\n/g, '\n');
      console.log(`   변환 후 길이: ${privateKeyPem.length}`);
    } else {
      console.log('✅ [DEBUG] Private key already has real newlines');
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
    console.log(`   binaryDer 길이: ${binaryDer.length}`);

    let key;
    try {
      key = await crypto.subtle.importKey(
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
    } catch (importError) {
      console.error('❌ [ERROR] Private key import 실패:', importError);
      throw new Error(`Failed to import private key: ${importError.message}`);
    }

    // JWT 생성 - djwt 라이브러리 사용
    console.log('🔐 [DEBUG] Creating JWT with djwt library');
    let jwt;
    try {
      // djwt의 create 함수 사용
      jwt = await create(header, payload, key);

      console.log('✅ [DEBUG] JWT 생성 완료 (djwt)');
      console.log(`   JWT 길이: ${jwt.length}`);
      console.log(`   JWT 첫 50자: ${jwt.substring(0, 50)}...`);
      console.log(`   Header: ${JSON.stringify(header)}`);
      console.log(`   Payload: ${JSON.stringify(payload)}`);
    } catch (jwtError) {
      console.error('❌ [ERROR] JWT 생성 실패:', jwtError);
      throw new Error(`Failed to create JWT: ${jwtError.message}`);
    }

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
    console.log(`🔍 [DEBUG] OAuth2 응답 헤더:`, Object.fromEntries(tokenResponse.headers.entries()));

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      console.error('❌ [ERROR] OAuth2 토큰 요청 실패:', errorText);
      console.error('🔍 [DEBUG] Response status:', tokenResponse.status);
      console.error('🔍 [DEBUG] Response headers:', Object.fromEntries(tokenResponse.headers.entries()));
      throw new Error(`Failed to get access token: ${tokenResponse.status} - ${errorText}`);
    }

    console.log('✅ [DEBUG] OAuth2 응답 성공, JSON 파싱 시작');
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
    if (error instanceof Error) {
      console.error('   Error name:', error.name);
      console.error('   Error message:', error.message);
      console.error('   Error stack:', error.stack);
    }
    // 환경변수 확인
    const hasServiceAccount = !!Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    console.log(`   환경변수 FIREBASE_SERVICE_ACCOUNT_JSON 존재: ${hasServiceAccount}`);
    if (hasServiceAccount) {
      try {
        const sa = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') || '{}');
        console.log(`   프로젝트 ID: ${sa.project_id || 'undefined'}`);
        console.log(`   클라이언트 이메일: ${sa.client_email || 'undefined'}`);
        console.log(`   Private Key 존재: ${!!sa.private_key}`);
      } catch (parseError) {
        console.error('   서비스 계정 JSON 파싱 실패:', parseError);
      }
    }
    throw error;
  }
}
async function sendFCMMessage(accessToken, fcmToken, title, body, data = {}, email, projectId) {
  try {
    console.log(`📤 [DEBUG] FCM 메시지 전송 시작`);
    console.log(`   대상: ${email || 'unknown'}`);
    console.log(`   토큰: ${fcmToken.substring(0, 20)}...`);
    console.log(`   제목: ${title}`);
    console.log(`   시각: ${new Date().toISOString()}`);
    if (!projectId) {
      throw new Error('Project ID not provided');
    }

    // 줄바꿈 이스케이프를 실제 개행으로 변환
    const normalizedBody = (body || '').replace(/\\n/g, '\n');

    // FCM data 필드는 모든 값이 문자열이어야 함
    const stringData = {};
    for (const [key, value] of Object.entries(data)) {
      if (value !== null && value !== undefined) {
        stringData[key] = typeof value === 'string' ? value : JSON.stringify(value);
      }
    }

    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: normalizedBody
        },
        data: stringData,
        android: {
          priority: 'high',
          notification: {
            sound: 'default'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              'content-available': 1
            }
          }
        }
      }
    };
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(message)
    });
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ [ERROR] FCM 전송 실패 (${email || 'unknown'}):`, errorText);
      console.error(`   Response Status: ${response.status}`);
      console.error(`   Response Headers:`, Object.fromEntries(response.headers.entries()));
      console.error(`   Project ID: ${projectId}`);
      console.error(`   Access Token (first 20 chars): ${accessToken.substring(0, 20)}...`);
      // 토큰 관련 에러 체크
      if (errorText.includes('UNREGISTERED') || errorText.includes('INVALID_ARGUMENT')) {
        console.log(`🗑️ [INFO] 유효하지 않은 FCM 토큰 감지: ${email || 'unknown'}`);
        // Supabase 환경변수 가져오기
        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
        if (supabaseUrl && supabaseServiceKey && email) {
          const supabase = createClient(supabaseUrl, supabaseServiceKey);
          // FCM 토큰 제거
          const { error: updateError } = await supabase.from('employees').update({
            fcm_token: null
          }).eq('email', email);
          if (updateError) {
            console.error('FCM 토큰 제거 실패:', updateError);
          } else {
            console.log(`✅ [INFO] ${email}의 유효하지 않은 FCM 토큰 제거 완료`);
          }
        }
      }
      return false;
    }
    const result = await response.json();
    console.log(`✅ [DEBUG] FCM 전송 성공 (${email || 'unknown'}):`, result.name);
    return true;
  } catch (error) {
    console.error(`❌ [ERROR] FCM 메시지 전송 중 오류 (${email || 'unknown'}):`, error);
    return false;
  }
}
// 역할별 FCM 토큰 조회 함수
async function getRoleTokens(supabase, role, excludeEmail) {
  try {
    console.log(`🔍 [DB 조회] ${role} 역할의 직원 조회 시작`);
    console.log(`   제외 이메일: ${excludeEmail || 'none'}`);

    // roles 통합 칼럼에서 역할 확인
    let query = supabase.from('employees')
      .select('email, name, fcm_token')
      .contains('roles', [role])
      .not('fcm_token', 'is', null);
    // 제외할 이메일이 있는 경우
    if (excludeEmail) {
      query = query.neq('email', excludeEmail);
    }

    console.log('🔍 [DB 조회] 쿼리 실행 중...');
    const { data: employees, error } = await query;

    if (error) {
      console.error('❌ [ERROR] 직원 조회 실패:', error);
      console.error('   Error details:', JSON.stringify(error, null, 2));
      return {
        tokens: [],
        emails: []
      };
    }

    console.log(`✅ [DB 조회] ${employees.length}명의 직원 조회 완료`);
    console.log('🔍 [DB 조회] 조회된 직원들:');
    employees.forEach((emp, index) => {
      console.log(`   ${index + 1}. ${emp.name} (${emp.email}): ${emp.fcm_token ? '토큰 있음' : '토큰 없음'}`);
    });

    const tokens = employees.map((emp)=>emp.fcm_token).filter(Boolean);
    const emails = employees.map((emp)=>emp.email).filter(Boolean);
    console.log(`📊 [DB 조회] 최종 결과: ${tokens.length}개 토큰, ${emails.length}개 이메일`);

    return {
      tokens,
      emails
    };
  } catch (error) {
    console.error('❌ [ERROR] getRoleTokens 실행 중 오류:', error);
    return {
      tokens: [],
      emails: []
    };
  }
}
// 부서별 FCM 토큰 조회 함수
async function getDepartmentTokens(supabase, department, excludeEmail) {
  try {
    console.log('🔍 [부서별 토큰 조회] 시작');
    console.log(`   대상 부서: ${department}`);
    console.log(`   제외 이메일: ${excludeEmail || 'none'}`);
    let query = supabase.from('employees').select('email, name, fcm_token, department').eq('department', department).not('fcm_token', 'is', null);
    // 제외할 이메일이 있는 경우
    if (excludeEmail) {
      query = query.neq('email', excludeEmail);
    }
    const { data: employees, error } = await query;
    if (error) {
      console.error('❌ [ERROR] 직원 조회 실패:', error);
      return {
        tokens: [],
        emails: []
      };
    }
    const tokens = [];
    const emails = [];
    const processedEmails = new Set();
    for (const emp of employees){
      console.log(`   - ${emp.name} (${emp.email}): ${emp.fcm_token ? '토큰 있음' : '토큰 없음'}`);
      if (emp.fcm_token && !processedEmails.has(emp.email)) {
        tokens.push(emp.fcm_token);
        emails.push(emp.email);
        processedEmails.add(emp.email);
      }
    }
    console.log(`✅ [부서별 토큰 조회] 완료: ${tokens.length}개 토큰`);
    return {
      tokens,
      emails
    };
  } catch (error) {
    console.error('❌ [ERROR] getDepartmentTokens 실행 중 오류:', error);
    return {
      tokens: [],
      emails: []
    };
  }
}
// 모든 관리자(Manager) FCM 토큰 조회 함수
async function getAllManagerTokens(supabase, includeRequester = false, requesterEmail) {
  try {
    console.log('🔍 [관리자 토큰 조회] 시작');
    console.log(`   요청자 포함: ${includeRequester}`);
    console.log(`   요청자 이메일: ${requesterEmail || 'none'}`);
    let query = supabase.from('employees').select('email, name, fcm_token, role').eq('role', 'Manager').not('fcm_token', 'is', null);
    // 요청자 제외 (includeRequester가 false인 경우만)
    if (!includeRequester && requesterEmail) {
      query = query.neq('email', requesterEmail);
    }
    const { data: managers, error } = await query;
    if (error) {
      console.error('❌ [ERROR] 관리자 조회 실패:', error);
      return {
        tokens: [],
        emails: []
      };
    }
    const tokens = [];
    const emails = [];
    const processedEmails = new Set();
    for (const manager of managers){
      console.log(`   - ${manager.name} (${manager.email}): ${manager.fcm_token ? '토큰 있음' : '토큰 없음'}`);
      if (manager.fcm_token && !processedEmails.has(manager.email)) {
        tokens.push(manager.fcm_token);
        emails.push(manager.email);
        processedEmails.add(manager.email);
      }
    }
    console.log(`✅ [관리자 토큰 조회] 완료: ${tokens.length}개 토큰`);
    return {
      tokens,
      emails
    };
  } catch (error) {
    console.error('❌ [ERROR] getAllManagerTokens 실행 중 오류:', error);
    return {
      tokens: [],
      emails: []
    };
  }
}
// 단일 사용자 FCM 토큰 조회 함수
async function getUserToken(supabase, userEmail) {
  try {
    const { data: employee, error } = await supabase.from('employees').select('fcm_token').eq('email', userEmail).single();
    if (error || !employee || !employee.fcm_token) {
      console.log(`No FCM token found for user: ${userEmail}`);
      return null;
    }
    return employee.fcm_token;
  } catch (error) {
    console.error('Error getting user token:', error);
    return null;
  }
}
// 구매 역할 기반 FCM 토큰 조회 함수
async function getPurchaseRoleTokens(supabase, roles, excludeEmail) {
  try {
    console.log('📦 [구매 알림] 대상 역할:', roles);
    // 역할에 해당하는 직원들 조회
    let query = supabase.from('employees').select('email, name, fcm_token, roles').not('fcm_token', 'is', null);
    // 제외할 이메일이 있는 경우
    if (excludeEmail) {
      query = query.neq('email', excludeEmail);
    }
    const { data: employees, error } = await query;
    if (error) {
      console.error('Error fetching employees for purchase roles:', error);
      return {
        tokens: [],
        emails: []
      };
    }
    const tokens = [];
    const emails = [];
    const processedEmails = new Set();
    // 각 직원의 roles 확인
    for (const emp of employees){
      if (!emp.roles || !Array.isArray(emp.roles)) continue;
      // 직원이 요청된 역할 중 하나라도 가지고 있는지 확인
      const hasRequiredRole = roles.some((role)=>emp.roles.includes(role));
      if (hasRequiredRole && emp.fcm_token && !processedEmails.has(emp.email)) {
        tokens.push(emp.fcm_token);
        emails.push(emp.email);
        processedEmails.add(emp.email);
        console.log(`  ✅ ${emp.name}(${emp.email}) - 역할: ${emp.roles.join(', ')}`);
      }
    }
    console.log(`📦 [구매 알림] 총 ${tokens.length}명에게 전송 예정`);
    return {
      tokens,
      emails
    };
  } catch (error) {
    console.error('Error getting purchase role tokens:', error);
    return {
      tokens: [],
      emails: []
    };
  }
}
// 요청자 이름으로 이메일 조회
async function getRequesterEmail(supabase, requesterName) {
  try {
    const { data: employee, error } = await supabase.from('employees').select('email').eq('name', requesterName).single();
    if (error || !employee) {
      console.error('Error finding requester email:', error);
      return null;
    }
    return employee.email;
  } catch (error) {
    console.error('Error in getRequesterEmail:', error);
    return null;
  }
}
Deno.serve(async (req)=>{
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    // 환경변수 검증
    console.log('🔍 [DEBUG] Supabase 환경변수 확인 시작');
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    console.log(`   SUPABASE_URL 존재: ${!!supabaseUrl}`);
    console.log(`   SUPABASE_URL: ${supabaseUrl || '없음'}`);
    console.log(`   SUPABASE_SERVICE_ROLE_KEY 존재: ${!!supabaseServiceKey}`);
    console.log(`   SUPABASE_SERVICE_ROLE_KEY 길이: ${supabaseServiceKey ? supabaseServiceKey.length : 0}`);

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('❌ [ERROR] Supabase 환경변수 누락');
      throw new Error('Missing Supabase environment variables');
    }

    // Supabase 클라이언트 초기화
    console.log('🔍 [DEBUG] Supabase 클라이언트 초기화 시작');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    console.log('✅ [DEBUG] Supabase 클라이언트 초기화 완료');
    // 요청 파싱
    const requestData = await req.json();
    let { type, title, body, data = {}, requester_department, requester_name, user_email, fcm_tokens, is_manager_request, skip_db_notification, purchase_order_number, vendor_name, payment_category, status, middle_manager_status, progress_type, targetEmail, notificationType, teams, individuals } = requestData;
    // Firebase Access Token 획득 (실패해도 계속 진행)
    let accessToken = null;
    let projectId = null;
    try {
      console.log('🔑 [DEBUG] Firebase 토큰 획득 시작');
      const firebaseAuth = await getFirebaseAccessToken();
      accessToken = firebaseAuth.accessToken;
      projectId = firebaseAuth.projectId;
      console.log('✅ [DEBUG] Firebase 토큰 획득 성공');
      console.log(`   Project ID: ${projectId}`);
      console.log(`   Access Token (first 20 chars): ${accessToken.substring(0, 20)}...`);
    } catch (error) {
      console.error('❌ [ERROR] Firebase 토큰 획득 실패:', error);
      console.error('   Error details:', JSON.stringify(error, null, 2));
      console.error('   Error name:', error?.name);
      console.error('   Error message:', error?.message);
      console.error('   Error stack:', error?.stack);

      // 환경변수 직접 확인
      console.log('🔍 [DEBUG] 환경변수 직접 확인:');
      const envVars = Deno.env.toObject();
      for (const [key, value] of Object.entries(envVars)) {
        if (key.includes('FIREBASE') || key.includes('SUPABASE')) {
          console.log(`   ${key}: ${value ? '설정됨 (길이: ' + value.length + ')' : '없음'}`);
        }
      }

      // Firebase 오류가 있어도 계속 진행
    }
    let targetTokens = [];
    let targetEmails = [];
    // 구매 관련 알림 처리
    if (type === 'purchase_requests') {  // s 있음!
      console.log('📦 [구매 알림] 신규 구매 요청 처리');
      // 신규 구매 요청은 middle_manager와 superadmin에게 전송
      const result = await getPurchaseRoleTokens(supabase, [
        'middle_manager',
        'superadmin'
      ]);
      targetTokens = result.tokens;
      targetEmails = result.emails;
      if (!title) title = '📦 새로운 구매 요청';
      if (!body) {
        body = purchase_order_number ? `${requester_name}님이 ${payment_category} 요청(${purchase_order_number})을 등록했습니다.` : `${requester_name}님이 새로운 구매 요청을 등록했습니다.`;
      }
    } else if (type === 'purchase_status_change') {
      console.log('🔄 [구매 알림] 구매 상태 변경 처리');
      console.log('  발주번호:', purchase_order_number);
      console.log('  상태:', status);
      console.log('  중간승인상태:', middle_manager_status);
      console.log('  카테고리:', payment_category);
      console.log('  진행타입:', progress_type);
      // 상태에 따라 대상 결정
      if (middle_manager_status === 'approved' && status === 'pending') {
        // 1차 승인 완료 -> 카테고리에 따른 최종 승인자에게
        let targetRoles = [
          'superadmin'
        ] // superadmin은 항상 포함
        ;
        if (payment_category === '발주') {
          targetRoles.push('raw_material_manager');
        } else if (payment_category === '구매 요청' || payment_category === '구매요청') {
          targetRoles.push('consumable_manager');
        } else {
          targetRoles.push('final_approver');
        }
        const result = await getPurchaseRoleTokens(supabase, targetRoles);
        targetTokens = result.tokens;
        targetEmails = result.emails;
        if (!title) title = '📋 1차 승인 완료';
        if (!body) body = `${requester_name}님의 ${payment_category}(${purchase_order_number})이 1차 승인되었습니다.`;
        // data 필드에 type 추가
        data = {
          ...data,
          type: 'final_approval_request',
          purchase_order_number: purchase_order_number || '',
          requester_name: requester_name || '',
          payment_category: payment_category || ''
        };
      } else if (status === 'approved') {
        // 최종 승인 처리
        const requesterEmail = await getRequesterEmail(supabase, requester_name);
        const userToken = requesterEmail ? await getUserToken(supabase, requesterEmail) : null;

        // 카테고리와 progress_type에 따라 알림 처리
        if (payment_category === '구매 요청' || payment_category === '구매요청') {
          // 구매 요청의 경우 - lead buyer에게만 알림
          const leadBuyerResult = await getPurchaseRoleTokens(supabase, [
            'lead buyer'
          ]);
          targetTokens = leadBuyerResult.tokens;
          targetEmails = leadBuyerResult.emails;

          if (progress_type === '선진행') {
            if (!title) title = '🚀 선진행 구매 요청';
            if (!body) body = `${requester_name}님의 선진행 ${payment_category}(${purchase_order_number})이 등록되었습니다. 구매 진행 부탁드립니다.`;
          } else {
            // 일반
            if (!title) title = '📦 구매 진행 요청';
            if (!body) body = `${requester_name}님의 ${payment_category}(${purchase_order_number})이 최종 승인 완료되었습니다. 구매 진행 부탁드립니다.`;
          }
        } else if (payment_category === '발주') {
          if (progress_type === '선진행') {
            // 선진행 + 발주는 알림 없음
            targetTokens = [];
            targetEmails = [];
          } else {
            // 일반 + 발주는 요청자에게만 알림
            if (userToken) {
              targetTokens = [userToken];
              targetEmails = [requesterEmail];
            } else {
              targetTokens = [];
              targetEmails = [];
            }
            if (!title) title = '📦 발주 진행 요청';
            if (!body) body = `${requester_name}님의 ${payment_category}(${purchase_order_number})이 최종 승인 완료되었습니다. 발주 진행 부탁드립니다.`;
          }
        }
        // data 필드에 type 추가
        data = {
          ...data,
          type: 'purchase_approved',
          purchase_order_number: purchase_order_number || '',
          requester_name: requester_name || '',
          payment_category: payment_category || '',
          progress_type: progress_type || ''
        };
      } else if (status === 'rejected' || middle_manager_status === 'rejected') {
        // 반려 -> 요청자에게
        const requesterEmail = await getRequesterEmail(supabase, requester_name);
        const userToken = requesterEmail ? await getUserToken(supabase, requesterEmail) : null;
        if (userToken) {
          targetTokens = [
            userToken
          ];
          targetEmails = [
            requesterEmail
          ];
        }
        if (!title) title = '❌ 구매 요청 반려';
        if (!body) body = `${requester_name}님의 ${payment_category}(${purchase_order_number})이 반려되었습니다.`;
      }
    } else if (type === 'transaction_statement_extracted') {
      console.log('🟠 [거래명세서 알림] 등록자에게 추출 완료 알림');

      const dataMap = data && typeof data === 'object' ? data : {};
      const uploaderName = dataMap['uploaded_by_name'] ||
        dataMap['uploader_name'] ||
        requester_name ||
        '알 수 없음';
      const uploaderEmail = dataMap['uploaded_by_email'] || '';
      const vendorName = dataMap['vendor_name'] || dataMap['vendorName'] || '';
      const grandTotal = dataMap['grand_total'] || dataMap['grandTotal'] || '';

      // 등록자에게만 알림 전송
      if (uploaderEmail) {
        const userToken = await getUserToken(supabase, uploaderEmail);
        if (userToken) {
          targetTokens = [userToken];
          targetEmails = [uploaderEmail];
          console.log(`  ✅ 등록자에게 알림: ${uploaderName} (${uploaderEmail})`);
        } else {
          console.log(`  ❌ 등록자 FCM 토큰 없음: ${uploaderName} (${uploaderEmail})`);
        }
      } else {
        console.log('  ❌ 등록자 이메일 정보 없음');
      }

      if (!title) title = '✅ 거래명세서 추출 완료';
      if (!body) {
        const parts = [];
        parts.push('거래명세서 추출이 완료되었습니다. 입고수량 체크 바랍니다.');
        if (vendorName) parts.push(`거래처: ${vendorName}`);
        if (grandTotal) {
          const formatted = Number(grandTotal).toLocaleString('ko-KR');
          parts.push(`금액: ₩${formatted}`);
        }
        body = parts.join('\n');
      }

      data = {
        ...dataMap,
        type: 'transaction_statement_extracted',
        statement_id: dataMap['statement_id'] || dataMap['statementId'] || '',
        image_url: dataMap['image_url'] || dataMap['imageUrl'] || '',
        uploaded_by_name: uploaderName,
        uploaded_by_email: uploaderEmail,
        uploaded_at: dataMap['uploaded_at'] || dataMap['uploadedAt'] || '',
        vendor_name: vendorName,
        grand_total: grandTotal,
        status: 'extracted'
      };
    } else if (type === 'transaction_statement_quantities_matched') {
      console.log('✅ [거래명세서 알림] 수량체크 완료 → lead buyer에게 알림');

      const dataMap = data && typeof data === 'object' ? data : {};
      const uploaderName = dataMap['uploaded_by_name'] || '알 수 없음';
      const vendorName = dataMap['vendor_name'] || '';
      const grandTotal = dataMap['grand_total'] || '';
      const statementCode = dataMap['statement_code'] || '';

      // lead buyer에게 알림 전송
      const result = await getPurchaseRoleTokens(supabase, ['lead buyer']);
      targetTokens = result.tokens;
      targetEmails = result.emails;

      if (!title) title = '📋 거래명세서 수량체크 완료';
      if (!body) {
        const parts = [];
        parts.push('수량체크가 완료되었습니다. 해당 거래명세서의 금액 체크 바랍니다.');
        if (vendorName) parts.push(`거래처: ${vendorName}`);
        if (grandTotal) {
          const formatted = Number(grandTotal).toLocaleString('ko-KR');
          parts.push(`금액: ₩${formatted}`);
        }
        body = parts.join('\n');
      }

      data = {
        ...dataMap,
        type: 'transaction_statement_quantities_matched',
        statement_id: dataMap['statement_id'] || '',
        vendor_name: vendorName,
        grand_total: grandTotal,
        statement_code: statementCode,
        uploaded_by_name: uploaderName
      };
    } else if (type === 'business_trip_approved') {
      console.log('✈️ [출장 알림] 출장 승인 → 요청자에게 카드 수령 알림');

      const dataMap = data && typeof data === 'object' ? data : {};
      const requesterEmail = dataMap['requester_email'] || '';
      const tripCode = dataMap['trip_code'] || '';
      const cardNumber = dataMap['card_number'] || '';

      if (requesterEmail) {
        const userToken = await getUserToken(supabase, requesterEmail);
        if (userToken) {
          targetTokens = [userToken];
          targetEmails = [requesterEmail];
          console.log(`  ✅ 요청자에게 알림: ${requesterEmail}`);
        } else {
          console.log(`  ❌ 요청자 FCM 토큰 없음: ${requesterEmail}`);
        }
      }

      if (!title) title = '✈️ 출장 승인 완료';
      if (!body) {
        const parts = ['출장 신청이 승인되었습니다.'];
        if (cardNumber) parts.push(`카드(${cardNumber})를 수령해 주세요.`);
        if (tripCode) parts.push(`출장번호: ${tripCode}`);
        body = parts.join('\n');
      }

      data = {
        ...dataMap,
        type: 'business_trip_approved',
      };
    } else if (type === 'card_usage_approved') {
      console.log('💳 [카드 알림] 카드 사용 승인 → 요청자에게 알림');

      const dataMap = data && typeof data === 'object' ? data : {};
      const requesterEmail = dataMap['requester_email'] || '';
      const cardNumber = dataMap['card_number'] || '';
      const usageCategory = dataMap['usage_category'] || '';

      if (requesterEmail) {
        const userToken = await getUserToken(supabase, requesterEmail);
        if (userToken) {
          targetTokens = [userToken];
          targetEmails = [requesterEmail];
          console.log(`  ✅ 요청자에게 알림: ${requesterEmail}`);
        } else {
          console.log(`  ❌ 요청자 FCM 토큰 없음: ${requesterEmail}`);
        }
      }

      if (!title) title = '💳 카드 사용 승인 완료';
      if (!body) {
        const parts = ['카드 사용 요청이 승인되었습니다.'];
        if (cardNumber) parts.push(`카드: ${cardNumber}`);
        if (usageCategory) parts.push(`용도: ${usageCategory}`);
        body = parts.join('\n');
      }

      data = {
        ...dataMap,
        type: 'card_usage_approved',
      };
    } else if (type === 'ai_service_reviewed') {
      console.log('🤖 [AI 서비스 신청서 알림] 검토완료 -> admin에게 알림');
      const result = await getPurchaseRoleTokens(supabase, ['admin']);
      targetTokens = result.tokens;
      targetEmails = result.emails;
    } else if (type === 'new_vendor_inquiry') {
      // 업체등록 요청 문의 접수 → lead buyer + superadmin에게 알림
      console.log('🏢 [업체등록 요청 알림] 신규 업체 등록 요청 → lead buyer, superadmin에게 알림');

      const dataMap = data && typeof data === 'object' ? data : {};
      const requesterName = dataMap['requester_name'] || '';
      const vendorName = dataMap['vendor_name'] || '';

      const result = await getPurchaseRoleTokens(supabase, ['lead buyer', 'superadmin']);
      targetTokens = result.tokens;
      targetEmails = result.emails;

      if (!title) title = '🏢 신규 업체 등록 요청';
      if (!body) {
        const parts = [];
        parts.push(`${requesterName || '직원'}님이 업체 등록을 요청했습니다.`);
        if (vendorName) parts.push(`업체명: ${vendorName}`);
        body = parts.join('\n');
      }

      data = {
        ...dataMap,
        type: 'new_vendor_inquiry'
      };
    } else if (type === 'vendor_edit_inquiry') {
      // 기존업체 수정 요청 문의 접수 → lead buyer + superadmin에게 알림
      console.log('✏️ [기존업체 수정 요청 알림] lead buyer, superadmin에게 알림');

      const dataMap = data && typeof data === 'object' ? data : {};
      const requesterName = dataMap['requester_name'] || '';
      const vendorName = dataMap['vendor_name'] || '';

      const result = await getPurchaseRoleTokens(supabase, ['lead buyer', 'superadmin']);
      targetTokens = result.tokens;
      targetEmails = result.emails;

      if (!title) title = '✏️ 기존업체 수정 요청';
      if (!body) {
        const parts = [];
        parts.push(`${requesterName || '직원'}님이 업체 정보 수정을 요청했습니다.`);
        if (vendorName) parts.push(`업체명: ${vendorName}`);
        body = parts.join('\n');
      }

      data = {
        ...dataMap,
        type: 'vendor_edit_inquiry'
      };
    } else if (type === 'shipping_edit_inquiry') {
      // 택배 주소록 수정 요청 문의 접수 → lead buyer + superadmin에게 알림
      console.log('📦 [택배 주소록 수정 요청 알림] lead buyer, superadmin에게 알림');

      const dataMap = data && typeof data === 'object' ? data : {};
      const requesterName = dataMap['requester_name'] || '';
      const companyName = dataMap['company_name'] || '';

      const result = await getPurchaseRoleTokens(supabase, ['lead buyer', 'superadmin']);
      targetTokens = result.tokens;
      targetEmails = result.emails;

      if (!title) title = '📦 택배 주소록 수정 요청';
      if (!body) {
        const parts = [];
        parts.push(`${requesterName || '직원'}님이 택배 주소록 수정을 요청했습니다.`);
        if (companyName) parts.push(`업체명: ${companyName}`);
        body = parts.join('\n');
      }

      data = {
        ...dataMap,
        type: 'shipping_edit_inquiry'
      };
    } else if (type === 'admin') {
      // 연차/출장 관리자 알림 - roles 기반
      console.log('📋 [연차/출장 알림] roles 기반 관리자 조회');

      // requester_department가 있으면 해당 부서 매니저 + superadmin
      // 없으면 모든 roles 관리자
      let query = supabase.from('employees')
        .select('email, name, fcm_token, roles, department')
        .not('fcm_token', 'is', null);

      const { data: employees, error } = await query;

      if (error) {
        console.error('Error fetching employees for admin notification:', error);
        targetTokens = [];
        targetEmails = [];
      } else {
        const tokens = [];
        const emails = [];
        const processedEmails = new Set();

        for (const emp of employees) {
          if (!emp.roles || !Array.isArray(emp.roles)) continue;

          let shouldNotify = false;

          // superadmin은 항상 알림
          if (emp.roles.includes('superadmin')) {
            shouldNotify = true;
            console.log(`  ✅ SuperAdmin: ${emp.name} (${emp.email})`);
          }
          // admin은 제외 (문서에 명시됨)
          else if (emp.roles.includes('admin')) {
            console.log(`  ⏭️ Admin 제외: ${emp.name} (${emp.email})`);
            continue;
          }
          // 부서별 매니저 확인
          else if (requester_department) {
            // 해당 부서 매니저인지 확인
            const departmentManagerRoles = {
              '개발1팀': '개발팀_manager',
              '개발2팀': '개발팀_manager',
              '개발3팀': '개발3팀_manager',
              '연구소': '연구소_manager',
              '경영팀': '경영팀_manager',
              'CAD': 'CAD_manager'
            };

            const requiredRole = departmentManagerRoles[requester_department];
            if (requiredRole && emp.roles.includes(requiredRole)) {
              shouldNotify = true;
              console.log(`  ✅ 부서 매니저: ${emp.name} (${emp.email}) - ${requiredRole}`);
            }
          }

          if (shouldNotify && emp.fcm_token && !processedEmails.has(emp.email)) {
            tokens.push(emp.fcm_token);
            emails.push(emp.email);
            processedEmails.add(emp.email);
          }
        }

        targetTokens = tokens;
        targetEmails = emails;
        console.log(`📊 [연차/출장 알림] 총 ${tokens.length}명에게 전송 예정`);
      }
    } else if (type === 'production_teams') {
      // 제작현황: 팀 배열(CM팀/생산팀/CAD/연구소) + 개인 배열 기반 발송
      console.log('🏭 [제작현황 알림] 대상 팀:', teams, '개인:', individuals);
      const teamList = Array.isArray(teams) ? teams : [];
      const individualList = Array.isArray(individuals) ? individuals : [];
      // 팀 단위 알림에서 제외할 인원 (개인 지정 발송은 유지)
      const PRODUCTION_TEAM_EXCLUDES = new Set(['hyun-woong.jeong@hansl.com', 'hee-seung.kim@hansl.com']);
      const tokens = [];
      const emails = [];
      const processedEmails = new Set();

      for (const team of teamList) {
        const result = (team === 'CAD' || team === '연구소')
          ? await getDepartmentTokens(supabase, team)
          : await getRoleTokens(supabase, team);
        result.emails.forEach((email, idx) => {
          if (!processedEmails.has(email) && !PRODUCTION_TEAM_EXCLUDES.has(email)) {
            tokens.push(result.tokens[idx]);
            emails.push(email);
            processedEmails.add(email);
          }
        });
      }

      for (const email of individualList) {
        if (processedEmails.has(email)) continue;
        const userToken = await getUserToken(supabase, email);
        if (userToken) {
          tokens.push(userToken);
          emails.push(email);
          processedEmails.add(email);
        }
      }

      // 사용자별 수신 설정(employees.notification_preferences.production_teams) 필터링
      // 항목 키: 신규 등록은 'production_new_row', 완료 이벤트는 data.field 값
      // (설정에 키가 없으면 기본 수신, 조회 실패 시에도 기존대로 전원 발송)
      const prodDataMap = data && typeof data === 'object' ? data : {};
      const prefKey = prodDataMap['type'] === 'production_new_row'
        ? 'production_new_row'
        : (prodDataMap['field'] || null);
      if (prefKey && emails.length > 0) {
        const { data: prefRows, error: prefError } = await supabase
          .from('employees')
          .select('email, notification_preferences')
          .in('email', emails);
        if (prefError) {
          console.error('❌ [제작현황 알림] 수신 설정 조회 실패(필터 없이 발송):', prefError);
        } else {
          const optedOut = new Set(
            (prefRows || [])
              .filter((row) => row.notification_preferences?.production_teams?.[prefKey] === false)
              .map((row) => row.email)
          );
          if (optedOut.size > 0) {
            const filteredTokens = [];
            const filteredEmails = [];
            emails.forEach((email, idx) => {
              if (optedOut.has(email)) {
                console.log(`  🔕 수신 거부(${prefKey}): ${email}`);
              } else {
                filteredTokens.push(tokens[idx]);
                filteredEmails.push(email);
              }
            });
            tokens.length = 0;
            tokens.push(...filteredTokens);
            emails.length = 0;
            emails.push(...filteredEmails);
          }
        }
      }

      targetTokens = tokens;
      targetEmails = emails;
      console.log(`📊 [제작현황 알림] 총 ${tokens.length}명에게 전송 예정`);
    } else if (type === 'manager') {
      // 부서 관리자 메시지 처리
      if (is_manager_request && requester_department) {
        // 부서별 관리자 메시지
        const deptResult = await getDepartmentTokens(supabase, requester_department, user_email);
        targetTokens = deptResult.tokens;
        targetEmails = deptResult.emails;
      } else {
        // 모든 관리자에게 전송
        const managerResult = await getAllManagerTokens(supabase, false, user_email);
        targetTokens = managerResult.tokens;
        targetEmails = managerResult.emails;
      }
    } else if (type === 'user' && user_email) {
      // 특정 사용자 메시지
      const userToken = await getUserToken(supabase, user_email);
      if (userToken) {
        targetTokens = [
          userToken
        ];
        targetEmails = [
          user_email
        ];
      }
    } else if (type === 'custom' && fcm_tokens && Array.isArray(fcm_tokens)) {
      // 직접 토큰 리스트 제공 (custom 타입)
      targetTokens = fcm_tokens;
    // title과 body는 요청에서 제공된 값 사용
    } else if (fcm_tokens && Array.isArray(fcm_tokens)) {
      // 직접 토큰 리스트 제공 (기존 로직)
      targetTokens = fcm_tokens;
    } else if (targetEmail) {
      // targetEmail로 특정 사용자에게 전송
      console.log('🎯 [targetEmail 처리] 대상 이메일:', targetEmail);
      const userToken = await getUserToken(supabase, targetEmail);
      if (userToken) {
        targetTokens = [userToken];
        targetEmails = [targetEmail];
        console.log('✅ [targetEmail] 토큰 조회 성공');
      } else {
        console.log('❌ [targetEmail] 토큰 조회 실패');
      }
    }
    if (targetTokens.length === 0) {
      return new Response(JSON.stringify({
        success: false,
        message: 'No FCM tokens found'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 400
      });
    }
    console.log(`📨 [알림 전송] 대상: ${targetEmails.join(', ')}`);
    console.log(`   총 ${targetTokens.length}명에게 전송`);
    // FCM 메시지 전송 (accessToken이 있는 경우만)
    let successCount = 0;
    console.log(`📤 [FCM 전송] 시작 - 토큰 수: ${targetTokens.length}`);
    console.log(`   Access Token 존재: ${!!accessToken}`);
    console.log(`   Project ID: ${projectId}`);

    if (accessToken && projectId && targetTokens.length > 0) {
      console.log('🚀 [FCM 전송] Firebase 토큰과 프로젝트 ID 확인됨, 전송 시작');
      const results = await Promise.all(targetTokens.map((token, index)=>sendFCMMessage(accessToken, token, title || '', body || '', data, targetEmails[index], projectId)));
      // 성공한 전송 수 계산
      successCount = results.filter((result)=>result).length;
      console.log(`📊 [전송 결과] ${successCount}/${targetTokens.length} 성공`);
    } else {
      console.log('❌ [FCM 전송] Firebase 토큰 또는 프로젝트 ID 없음, FCM 전송 건너뜀');
      console.log(`   Access Token: ${accessToken ? '있음' : '없음'}`);
      console.log(`   Project ID: ${projectId || '없음'}`);
      console.log(`   Target Tokens: ${targetTokens.length}개`);
    }
    // DB에 알림 기록 저장 (skip_db_notification이 true가 아닌 경우)
    if (!skip_db_notification && type !== 'custom') {
      try {
        // 각 대상자별로 개별 알림 저장
        if (targetEmails.length > 0) {
          const notifications = targetEmails.map((email)=>({
              user_email: email,
              title: title || '',
              body: body || '',
              type: type,
              data: data || {},
              is_read: false
            }));
          const { error: dbError } = await supabase.from('notifications').insert(notifications);
          if (dbError) {
            console.error('Failed to save notifications to DB:', dbError);
          } else {
            console.log(`✅ ${notifications.length} notifications saved to DB`);
          }
        }
      } catch (dbError) {
        console.error('Error saving notifications to DB:', dbError);
      }
    }
    return new Response(JSON.stringify({
      success: true,
      message: `Successfully sent ${successCount} out of ${targetTokens.length} notifications`,
      details: {
        total: targetTokens.length,
        successful: successCount,
        failed: targetTokens.length - successCount,
        recipients: targetEmails
      }
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 200
    });
  } catch (error) {
    console.error('❌ [FATAL ERROR]:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred',
      details: error instanceof Error ? error.stack : undefined
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 500
    });
  }
});
