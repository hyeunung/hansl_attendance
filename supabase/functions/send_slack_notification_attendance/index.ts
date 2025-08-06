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
    
    // attendance_role에 'admin'이 포함된 사용자들 조회
    const { data: admins, error } = await supabase
      .from('employees')
      .select('slack_id, name')
      .not('slack_id', 'is', null)
      .filter('attendance_role', 'cs', '{"admin"}')
    
    if (error) {
      console.error('Error fetching admin slack IDs:', error)
      return []
    }

    if (!admins || admins.length === 0) {
      console.log('⚠️ admin 권한을 가진 사용자가 없습니다.')
      return []
    }

    console.log('찾은 admin 사용자:', admins)
    const slackIds = admins.map((admin: any) => admin.slack_id)
    console.log(`📊 총 ${slackIds.length}명의 관리자에게 문의 메시지 전송 예정: ${slackIds.join(', ')}`)
    
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
  // 한국 시간(KST, UTC+9)으로 변환
  const now = new Date()
  // toLocaleString을 사용하여 한국 시간대로 변환
  const kstDate = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Seoul"}))
  const year = kstDate.getFullYear()
  const month = (kstDate.getMonth() + 1).toString().padStart(2, '0')
  const day = kstDate.getDate().toString().padStart(2, '0')
  const hours = kstDate.getHours().toString().padStart(2, '0')
  const minutes = kstDate.getMinutes().toString().padStart(2, '0')
  const formattedTime = `${year}-${month}-${day} ${hours}:${minutes} (KST)`

  const userInfo = userSlackId ? `${userName} (<@${userSlackId}>)` : userName
  
  return {
    username: `${userName} (HANSL 근태앱)`,
    icon_emoji: ':raising_hand:',
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
      console.error('❌ Supabase 환경변수가 설정되지 않았습니다')
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Supabase environment variables not configured',
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500 
        }
      )
    }

    if (!slackWebhookUrl || slackWebhookUrl === 'YOUR_SLACK_WEBHOOK_URL_HERE') {
      console.error('❌ Slack Webhook URL이 설정되지 않았습니다')
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Slack webhook URL not configured. Please contact administrator.',
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400 
        }
      )
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

    // Webhook으로 채널에 메시지 전송
    // 관리자들을 멘션하여 알림
    const adminMentions = adminSlackIds.map(id => `<@${id}>`).join(' ')
    
    // text 필드 추가 (Slack 알림에 표시됨)
    const channelMessage = {
      ...slackMessage,
      text: `🆘 새로운 문의가 접수되었습니다! ${adminMentions}`
    }
    
    console.log('📮 Slack 채널로 문의 메시지 전송 중...')
    const success = await sendSlackMessage(slackWebhookUrl, channelMessage)

    console.log(`📊 근태앱 문의 메시지 전송 ${success ? '성공' : '실패'} - ${adminSlackIds.length}명의 관리자에게 멘션`)

    return new Response(
      JSON.stringify({
        success: success,
        message: success 
          ? `Inquiry sent successfully. ${adminSlackIds.length} admins mentioned.`
          : 'Failed to send inquiry to Slack channel',
        mentioned_admins: adminSlackIds.length,
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