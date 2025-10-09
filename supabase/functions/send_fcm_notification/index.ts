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
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not found in environment variables');
    }
    
    console.log('✅ [DEBUG] 환경변수에서 Firebase 키 로드 완료');
    
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
      sub: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    };
    
    console.log('📋 [DEBUG] JWT Payload:', JSON.stringify(payload, null, 2));
    // JWT 생성 - Private Key 처리 수정
    const privateKeyPem = serviceAccount.private_key
      .replace(/\\n/g, '\n');
    
    // PEM 형식에서 base64 부분만 추출
    const pemContents = privateKeyPem
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\s/g, '');
    
    // base64를 ArrayBuffer로 변환
    const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));
    
    // crypto.subtle.importKey 사용
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
    const jwt = await create(header, payload, key);
    console.log('🔐 [DEBUG] JWT 생성 완료');
    // Google OAuth2 토큰 요청
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
    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      console.error('❌ [ERROR] OAuth2 토큰 요청 실패:', errorText);
      console.error('🔍 [DEBUG] Response status:', tokenResponse.status);
      console.error('🔍 [DEBUG] Response headers:', Object.fromEntries(tokenResponse.headers.entries()));
      throw new Error(`Failed to get access token: ${tokenResponse.status} - ${errorText}`);
    }
    const tokenData = await tokenResponse.json();
    console.log('✅ [DEBUG] OAuth2 토큰 획득 성공');
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
    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: body
        },
        data: data,
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
              'content-available': 1,
              badge: 1
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
    let query = supabase.from('employees').select('email, name, fcm_token').eq('role', role).not('fcm_token', 'is', null);
    // 제외할 이메일이 있는 경우
    if (excludeEmail) {
      query = query.neq('email', excludeEmail);
    }
    const { data: employees, error } = await query;
    if (error) {
      console.error('Error fetching employees:', error);
      return {
        tokens: [],
        emails: []
      };
    }
    const tokens = employees.map((emp)=>emp.fcm_token).filter(Boolean);
    const emails = employees.map((emp)=>emp.email).filter(Boolean);
    console.log(`Found ${tokens.length} ${role} FCM tokens`);
    return {
      tokens,
      emails
    };
  } catch (error) {
    console.error('Error in getRoleTokens:', error);
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
    let query = supabase.from('employees').select('email, name, fcm_token, purchase_role').not('fcm_token', 'is', null);
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
    // 각 직원의 purchase_role 확인
    for (const emp of employees){
      if (!emp.purchase_role || !Array.isArray(emp.purchase_role)) continue;
      // 직원이 요청된 역할 중 하나라도 가지고 있는지 확인
      const hasRequiredRole = roles.some((role)=>emp.purchase_role.includes(role));
      if (hasRequiredRole && emp.fcm_token && !processedEmails.has(emp.email)) {
        tokens.push(emp.fcm_token);
        emails.push(emp.email);
        processedEmails.add(emp.email);
        console.log(`  ✅ ${emp.name}(${emp.email}) - 역할: ${emp.purchase_role.join(', ')}`);
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
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables');
    }
    // Supabase 클라이언트 초기화
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // 요청 파싱
    const requestData = await req.json();
    let { type, title, body, data = {}, requester_department, requester_name, user_email, fcm_tokens, is_manager_request, skip_db_notification, purchase_order_number, vendor_name, payment_category, status, middle_manager_status, progress_type } = requestData;
    // Firebase Access Token 획득 (실패해도 계속 진행)
    let accessToken = null;
    let projectId = null;
    try {
      const firebaseAuth = await getFirebaseAccessToken();
      accessToken = firebaseAuth.accessToken;
      projectId = firebaseAuth.projectId;
    } catch (error) {
      console.error('Firebase 토큰 획득 실패, 알림은 DB에만 저장됩니다:', error);
      // Firebase 오류가 있어도 계속 진행
    }
    let targetTokens = [];
    let targetEmails = [];
    // 구매 관련 알림 처리
    if (type === 'purchase_requests') {  // s 있음!
      console.log('📦 [구매 알림] 신규 구매 요청 처리');
      // 신규 구매 요청은 middle_manager와 app_admin에게 전송
      const result = await getPurchaseRoleTokens(supabase, [
        'middle_manager',
        'app_admin'
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
          'app_admin'
        ] // app_admin은 항상 포함
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
    } else if (type === 'admin') {
      // 연차/출장 관리자 알림 - attendance_role 기반
      console.log('📋 [연차/출장 알림] attendance_role 기반 관리자 조회');
      
      // requester_department가 있으면 해당 부서 매니저 + superadmin
      // 없으면 모든 attendance_role 관리자
      let query = supabase.from('employees')
        .select('email, name, fcm_token, attendance_role, department')
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
          if (!emp.attendance_role || !Array.isArray(emp.attendance_role)) continue;
          
          let shouldNotify = false;
          
          // superadmin은 항상 알림
          if (emp.attendance_role.includes('superadmin')) {
            shouldNotify = true;
            console.log(`  ✅ SuperAdmin: ${emp.name} (${emp.email})`);
          }
          // admin은 제외 (문서에 명시됨)
          else if (emp.attendance_role.includes('admin')) {
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
              '경영지원팀': '경영지원팀_manager',
              'CAD': 'CAD_manager'
            };
            
            const requiredRole = departmentManagerRoles[requester_department];
            if (requiredRole && emp.attendance_role.includes(requiredRole)) {
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
    if (accessToken && projectId && targetTokens.length > 0) {
      const results = await Promise.all(targetTokens.map((token, index)=>sendFCMMessage(accessToken, token, title || '', body || '', data, targetEmails[index], projectId)));
      // 성공한 전송 수 계산
      successCount = results.filter((result)=>result).length;
      console.log(`📊 [전송 결과] ${successCount}/${targetTokens.length} 성공`);
    } else {
      console.log('📊 [전송 결과] Firebase 토큰 또는 프로젝트 ID 없음, FCM 전송 건너뜀');
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