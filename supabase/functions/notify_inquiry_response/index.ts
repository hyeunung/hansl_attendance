import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')!

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Parse request body
    const { inquiryId, userId, status, resolutionNote } = await req.json()

    console.log('📬 문의 답변 알림 처리:', { inquiryId, userId, status })

    // 사용자의 FCM 토큰 가져오기
    const { data: employee, error: employeeError } = await supabase
      .from('employees')
      .select('fcm_token, name, email')
      .eq('id', userId)
      .single()

    if (employeeError || !employee?.fcm_token) {
      console.log('⚠️ FCM 토큰을 찾을 수 없음:', employeeError)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'FCM 토큰을 찾을 수 없습니다' 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200 
        }
      )
    }

    // 상태에 따른 알림 메시지 생성
    let title = '문의 답변 도착'
    let body = '문의에 대한 답변이 도착했습니다.'
    
    if (status === 'resolved') {
      title = '✅ 문의가 처리 완료되었습니다'
      body = resolutionNote || '요청하신 문의가 처리 완료되었습니다. 앱에서 확인해주세요.'
    } else if (status === 'in_progress') {
      title = '🔄 문의 처리중'
      body = '문의를 확인하고 처리중입니다. 조금만 기다려주세요.'
    } else if (status === 'closed') {
      title = '📌 문의가 종료되었습니다'
      body = resolutionNote || '문의가 종료 처리되었습니다.'
    }

    // FCM 푸시 알림 전송
    const fcmMessage = {
      to: employee.fcm_token,
      notification: {
        title,
        body,
        sound: 'default',
        badge: 1,
      },
      data: {
        type: 'inquiry_response',
        inquiry_id: inquiryId.toString(),
        status,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      priority: 'high',
    }

    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${fcmServerKey}`,
      },
      body: JSON.stringify(fcmMessage),
    })

    const fcmResult = await fcmResponse.json()

    if (fcmResponse.ok && fcmResult.success === 1) {
      console.log('✅ FCM 푸시 알림 전송 성공')
      
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: '푸시 알림이 전송되었습니다' 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200 
        }
      )
    } else {
      console.error('❌ FCM 전송 실패:', fcmResult)
      
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'FCM 전송 실패',
          error: fcmResult 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200 
        }
      )
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 
      }
    )
  }
})