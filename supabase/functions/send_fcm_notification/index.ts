// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate, verify } from 'https://deno.land/x/djwt@v3.0.2/mod.ts'

console.log("Hello from Functions!")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FCMRequest {
  type: 'admin' | 'user'
  title: string
  body: string
  data?: Record<string, string>
  requester_department?: string
  requester_email?: string
  user_email?: string
  fcm_tokens?: string[]
  is_manager_request?: boolean
}

interface ServiceAccount {
  type: string
  project_id: string
  private_key_id: string
  private_key: string
  client_email: string
  client_id: string
  auth_uri: string
  token_uri: string
  auth_provider_x509_cert_url: string
  client_x509_cert_url: string
}

async function getFirebaseAccessToken(): Promise<string> {
  try {
    // 환경변수에서 서비스 계정 JSON 가져오기
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON environment variable is not set')
    }

    console.log('🔍 환경변수 길이:', serviceAccountJson.length)
    console.log('🔍 환경변수 시작 부분:', serviceAccountJson.substring(0, 100))

    let serviceAccount: ServiceAccount
    try {
      serviceAccount = JSON.parse(serviceAccountJson)
    } catch (parseError) {
      console.error('❌ JSON 파싱 에러:', parseError)
      console.error('❌ 문제가 된 JSON 일부:', serviceAccountJson.substring(0, 500))
      throw new Error(`Failed to parse service account JSON: ${parseError.message}`)
    }
    
    console.log('✅ JSON 파싱 성공, project_id:', serviceAccount.project_id)
    
    // JWT Header
    const header = {
      alg: 'RS256',
      typ: 'JWT',
    }

    // JWT Payload
    const now = Math.floor(Date.now() / 1000)
    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600, // 1시간
    }

    // Private Key 처리
    const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n')
    console.log('🔑 Private Key 길이:', privateKey.length)
    
    // PEM 형식에서 Base64 부분만 추출
    const pemHeader = '-----BEGIN PRIVATE KEY-----'
    const pemFooter = '-----END PRIVATE KEY-----'
    
    const privateKeyBase64 = privateKey
      .replace(pemHeader, '')
      .replace(pemFooter, '')
      .replace(/\s/g, '') // 모든 공백 제거
    
    console.log('🔑 Base64 Private Key 길이:', privateKeyBase64.length)
    
    let cryptoKey
    try {
      // Base64를 ArrayBuffer로 디코딩
      const privateKeyBuffer = Uint8Array.from(atob(privateKeyBase64), c => c.charCodeAt(0))
      
      cryptoKey = await crypto.subtle.importKey(
        'pkcs8',
        privateKeyBuffer,
        {
          name: 'RSASSA-PKCS1-v1_5',
          hash: 'SHA-256',
        },
        false,
        ['sign']
      )
    } catch (keyError) {
      console.error('❌ Private Key 임포트 실패:', keyError)
      throw new Error(`Failed to import private key: ${keyError.message}`)
    }

    // JWT 생성
    const jwt = await create(header, payload, cryptoKey)
    console.log('✅ JWT 생성 성공')

    // OAuth 토큰 요청
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error('❌ OAuth 토큰 요청 실패:', errorText)
      throw new Error(`Failed to get access token: ${tokenResponse.status} ${errorText}`)
    }

    const tokenData = await tokenResponse.json()
    console.log('✅ Firebase Access Token 획득 성공')
    return tokenData.access_token

  } catch (error) {
    console.error('❌ Firebase Access Token 획득 실패:', error)
    throw error
  }
}

async function sendFCMMessage(
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<boolean> {
  try {
    const projectId = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') || '{}').project_id
    if (!projectId) {
      throw new Error('Project ID not found in service account')
    }

    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: data,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            priority: 'high',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              'content-available': 1,
            },
          },
        },
      },
    }

    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`FCM API error: ${response.status} ${errorText}`)
      return false
    }

    const result = await response.json()
    console.log('✅ FCM message sent successfully:', result.name)
    return true

  } catch (error) {
    console.error('❌ Error sending FCM message:', error)
    return false
  }
}

async function getAdminAndManagerTokens(supabase: any, requesterDepartment?: string, requesterEmail?: string, isManagerRequest?: boolean): Promise<string[]> {
  try {
    console.log('📊 관리자 및 부서 관리자 FCM 토큰 조회 시작...')
    
    // 모든 직원 조회 (FCM 토큰이 있는)
    const { data: allEmployees, error } = await supabase
      .from('employees')
      .select('email, name, fcm_token, attendance_role')
      .not('fcm_token', 'is', null)
    
    if (error) {
      console.error('Error fetching employees:', error)
      return []
    }

    const tokens: string[] = []
    const processedEmails = new Set<string>()

    // Admin 필터링
    const adminList = allEmployees.filter((emp: any) => {
      const attendanceRole = emp.attendance_role
      if (attendanceRole && Array.isArray(attendanceRole)) {
        return attendanceRole.includes('admin')
      }
      return false
    })

    if (isManagerRequest) {
      // Manager 신청 → Admin에게만 알림
      console.log('👑 Manager 신청이므로 Admin에게만 알림 전송')
      
      for (const admin of adminList) {
        if (admin.fcm_token && !processedEmails.has(admin.email)) {
          tokens.push(admin.fcm_token)
          processedEmails.add(admin.email)
          console.log(`📧 Admin: ${admin.name} (${admin.email})`)
        }
      }
    } else {
      // 일반직원 신청 → Admin + 해당 부서 Manager 둘 다 알림
      console.log('👤 일반직원 신청이므로 Admin + 해당 부서 Manager에게 알림 전송')
      
      // Admin FCM 토큰 추가
      for (const admin of adminList) {
        if (admin.fcm_token && !processedEmails.has(admin.email)) {
          tokens.push(admin.fcm_token)
          processedEmails.add(admin.email)
          console.log(`📧 Admin: ${admin.name} (${admin.email})`)
        }
      }
      
      // 부서별 관리자 매핑
      const getManagerByDepartment = (department: string): string => {
        switch (department) {
          case '개발1팀':
          case '개발2팀':
            return '개발팀_manager'
          case '개발3팀':
            return '개발3팀_manager'
          case '연구소':
            return '연구소_manager'
          case '경영지원팀':
            return '경영지원팀_manager'
          case 'CAD':
            return 'CAD_manager'
          default:
            return ''
        }
      }

      // 해당 부서 Manager FCM 토큰 추가
      if (requesterDepartment) {
        const managerRole = getManagerByDepartment(requesterDepartment)
        if (managerRole) {
          const departmentManagers = allEmployees.filter((emp: any) => {
            const attendanceRole = emp.attendance_role
            if (attendanceRole && Array.isArray(attendanceRole)) {
              return attendanceRole.includes(managerRole)
            }
            return false
          })

          // 부서 관리자 FCM 토큰 추가 (중복 제거)
          for (const manager of departmentManagers) {
            if (manager.fcm_token && !processedEmails.has(manager.email)) {
              tokens.push(manager.fcm_token)
              processedEmails.add(manager.email)
              console.log(`🏢 ${requesterDepartment} 관리자: ${manager.name} (${manager.email})`)
            }
          }
        }
      }
    }

    console.log(`📊 총 ${tokens.length}명에게 알림 전송 예정`)
    return tokens

  } catch (error) {
    console.error('Error getting admin and manager tokens:', error)
    return []
  }
}

async function getUserToken(supabase: any, userEmail: string): Promise<string | null> {
  try {
    const { data: user, error } = await supabase
      .from('employees')
      .select('email, name, fcm_token')
      .eq('email', userEmail)
      .not('fcm_token', 'is', null)
      .maybeSingle()
    
    if (error || !user) {
      console.log(`⚠️ ${userEmail} 사용자를 찾을 수 없거나 FCM 토큰이 없습니다.`)
      return null
    }

    console.log(`📲 사용자: ${user.name} (${user.email})`)
    return user.fcm_token

  } catch (error) {
    console.error('Error getting user token:', error)
    return null
  }
}

Deno.serve(async (req: Request) => {
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // 환경변수 검증
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables')
    }

    // Supabase 클라이언트 초기화
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 요청 파싱
    const requestData: FCMRequest = await req.json()
    const { type, title, body, data = {}, requester_department, requester_email, user_email, fcm_tokens, is_manager_request } = requestData

    console.log(`🔔 FCM 알림 요청: ${type} - ${title}`)

    // Firebase Access Token 획득
    const accessToken = await getFirebaseAccessToken()
    console.log('✅ Firebase access token 획득 완료')

    let targetTokens: string[] = []

    if (type === 'admin') {
      // 관리자들에게 알림
      targetTokens = await getAdminAndManagerTokens(supabase, requester_department, requester_email, is_manager_request)
    } else if (type === 'user' && user_email) {
      // 특정 사용자에게 알림
      const userToken = await getUserToken(supabase, user_email)
      if (userToken) {
        targetTokens = [userToken]
      }
    } else if (fcm_tokens && Array.isArray(fcm_tokens)) {
      // 직접 토큰 리스트 제공
      targetTokens = fcm_tokens
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'No FCM tokens found',
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400 
        }
      )
    }

    // 각 토큰에 대해 FCM 메시지 전송
    let successCount = 0
    let failureCount = 0

    for (const token of targetTokens) {
      const success = await sendFCMMessage(accessToken, token, title, body, data)
      if (success) {
        successCount++
      } else {
        failureCount++
      }
    }

    console.log(`📊 알림 전송 완료: ${successCount}성공 / ${failureCount}실패 / ${targetTokens.length}총`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `FCM notifications sent: ${successCount} success, ${failureCount} failure`,
        total: targetTokens.length,
        success_count: successCount,
        failure_count: failureCount,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error('❌ Edge Function error:', error)
  return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 
      }
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/send_fcm_notification' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
