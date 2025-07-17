// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Hello from Slack Attendance Inquiry Functions!")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface InquiryRequest {
  type: 'inquiry'
  title: string
  message: string
  inquiry_content: string
  user_email: string
  user_name: string
  requester_department?: string
  requester_email?: string
}

async function getAdminSlackIds(supabase: any): Promise<string[]> {
  try {
    console.log('📊 관리자 Slack ID 조회 시작... (근태앱 문의)')
    
    // 관리자들 조회 (Slack ID가 있는)
    const { data: allEmployees, error } = await supabase
      .from('employees')
      .select('email, name, slack_id, attendance_role')
      .not('slack_id', 'is', null)
    
    if (error) {
      console.error('Error fetching employees:', error)
      return []
    }

    const slackIds: string[] = []
    const processedEmails = new Set<string>()

    // Admin 필터링
    const adminList = allEmployees.filter((emp: any) => {
      const attendanceRole = emp.attendance_role
      if (attendanceRole && Array.isArray(attendanceRole)) {
        return attendanceRole.includes('admin')
      }
      return false
    })

    // Admin Slack ID 추가
    for (const admin of adminList) {
      if (admin.slack_id && !processedEmails.has(admin.email)) {
        slackIds.push(admin.slack_id)
        processedEmails.add(admin.email)
        console.log(`📧 Admin: ${admin.name} (${admin.email})`)
      }
    }

    console.log(`📊 총 ${slackIds.length}명의 관리자에게 문의 메시지 전송 예정`)
    return slackIds

  } catch (error) {
    console.error('Error getting admin slack IDs:', error)
    return []
  }
}

async function getUserSlackId(supabase: any, userEmail: string): Promise<string | null> {
  try {
    const { data: user, error } = await supabase
      .from('employees')
      .select('email, name, slack_id')
      .eq('email', userEmail)
      .not('slack_id', 'is', null)
      .maybeSingle()
    
    if (error || !user) {
      console.log(`⚠️ ${userEmail} 사용자를 찾을 수 없거나 Slack ID가 없습니다.`)
      return null
    }

    console.log(`📲 문의자: ${user.name} (${user.email})`)
    return user.slack_id

  } catch (error) {
    console.error('Error getting user slack ID:', error)
    return null
  }
}

async function sendSlackMessage(webhookUrl: string, message: any): Promise<boolean> {
  try {
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message),
    })

    if (response.ok) {
      console.log('✅ Slack message sent successfully')
      return true
    } else {
      const errorText = await response.text()
      console.error(`❌ Slack API error: ${response.status} ${errorText}`)
      return false
    }

  } catch (error) {
    console.error('❌ Error sending Slack message:', error)
    return false
  }
}

function buildInquirySlackMessage(message: string, userEmail: string, userName: string, userSlackId?: string): any {
  const timestamp = new Date()
  const formattedTime = `${timestamp.getFullYear()}-${(timestamp.getMonth() + 1).toString().padStart(2, '0')}-${timestamp.getDate().toString().padStart(2, '0')} ${timestamp.getHours().toString().padStart(2, '0')}:${timestamp.getMinutes().toString().padStart(2, '0')}`

  const userInfo = userSlackId ? `${userName} (<@${userSlackId}>)` : userName
  
  return {
    username: 'HANSL 근태앱 문의 시스템',
    icon_emoji: ':question:',
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '🆘 HANSL 근태앱 문의사항',
        }
      },
      {
        type: 'section',
        fields: [
          {
            type: 'mrkdwn',
            text: `*문의자:*\n${userInfo}`
          },
          {
            type: 'mrkdwn',
            text: `*이메일:*\n${userEmail}`
          },
          {
            type: 'mrkdwn',
            text: `*문의시간:*\n${formattedTime}`
          }
        ]
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*문의내용:*\n\`\`\`${message}\`\`\``
        }
      },
      {
        type: 'divider'
      },
      {
        type: 'context',
        elements: [
          {
            type: 'mrkdwn',
            text: userSlackId 
              ? `📱 HANSL 근태관리 시스템 | 답장하려면 <@${userSlackId}>를 멘션하세요.`
              : `📱 HANSL 근태관리 시스템 | 답장은 ${userEmail}로 이메일을 보내주세요.`
          }
        ]
      }
    ]
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
    const slackWebhookUrl = Deno.env.get('SLACK_WEBHOOK_URL')
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables')
    }

    if (!slackWebhookUrl || slackWebhookUrl === 'YOUR_SLACK_WEBHOOK_URL_HERE') {
      throw new Error('Slack webhook URL not configured')
    }

    // Supabase 클라이언트 초기화
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 요청 파싱
    const requestData: InquiryRequest = await req.json()
    const { 
      type, 
      title, 
      message, 
      inquiry_content,
      user_email,
      user_name
    } = requestData

    console.log(`🔔 근태앱 문의 요청: ${title}`)

    // 문의하기 타입만 처리
    if (type !== 'inquiry') {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Only inquiry type is supported',
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400 
        }
      )
    }

    // 관리자들의 Slack ID 조회
    const adminSlackIds = await getAdminSlackIds(supabase)
    
    if (adminSlackIds.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'No admin Slack IDs found',
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400 
        }
      )
    }

    // 문의자의 Slack ID 조회 (멘션용)
    const userSlackId = await getUserSlackId(supabase, user_email)

    // 슬랙 메시지 구성
    const messageContent = inquiry_content || message
    const slackMessage = buildInquirySlackMessage(messageContent, user_email, user_name, userSlackId || undefined)

    // 각 관리자에게 메시지 전송
    let successCount = 0
    let failureCount = 0

    for (const adminSlackId of adminSlackIds) {
      // DM으로 전송
      const messageWithChannel = {
        ...slackMessage,
        channel: `@${adminSlackId}`
      }
      
      const success = await sendSlackMessage(slackWebhookUrl, messageWithChannel)
      if (success) {
        successCount++
      } else {
        failureCount++
      }
    }

    console.log(`📊 근태앱 문의 메시지 전송 완료: ${successCount}성공 / ${failureCount}실패 / ${adminSlackIds.length}총`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Inquiry sent to ${successCount} admins: ${successCount} success, ${failureCount} failure`,
        total: adminSlackIds.length,
        success_count: successCount,
        failure_count: failureCount,
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error('❌ Slack Inquiry Edge Function error:', error)
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