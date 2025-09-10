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
    const { inquiryId, userName, subject, inquiryType } = await req.json()

    console.log('🔔 새 문의 알림 처리:', { inquiryId, userName, subject })

    // 모든 app_admin의 FCM 토큰 가져오기
    const { data: admins, error: adminError } = await supabase
      .from('employees')
      .select('id, name, email, fcm_token')
      .or('purchase_role.ilike.%app_admin%')

    if (adminError || !admins || admins.length === 0) {
      console.log('⚠️ app_admin을 찾을 수 없음:', adminError)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'app_admin을 찾을 수 없습니다' 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200 
        }
      )
    }

    // 문의 유형 한글 변환
    const getInquiryTypeLabel = (type: string) => {
      switch(type) {
        case 'bug': return '오류';
        case 'modify': return '수정 요청';
        case 'delete': return '삭제 요청';
        case 'other': return '기타';
        default: return type;
      }
    }

    // 알림 메시지 생성
    const title = '🆕 새 문의가 도착했습니다'
    const body = `${userName}님의 [${getInquiryTypeLabel(inquiryType)}] 문의\n"${subject}"`

    // FCM 토큰이 있는 관리자들에게만 푸시 알림 전송
    const sendPromises = admins
      .filter(admin => admin.fcm_token)
      .map(async (admin) => {
        const fcmMessage = {
          to: admin.fcm_token,
          notification: {
            title,
            body,
            sound: 'default',
            badge: 1,
            priority: 'high',
          },
          data: {
            type: 'new_inquiry',
            inquiry_id: inquiryId.toString(),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          priority: 'high',
        }

        try {
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
            console.log(`✅ ${admin.name}(${admin.email})에게 푸시 알림 전송 성공`)
            return { success: true, admin: admin.email }
          } else {
            console.error(`❌ ${admin.name}에게 전송 실패:`, fcmResult)
            return { success: false, admin: admin.email, error: fcmResult }
          }
        } catch (error) {
          console.error(`❌ ${admin.name}에게 전송 중 오류:`, error)
          return { success: false, admin: admin.email, error: error.message }
        }
      })

    const results = await Promise.all(sendPromises)
    const successCount = results.filter(r => r.success).length

    console.log(`📊 전송 결과: ${successCount}/${admins.filter(a => a.fcm_token).length}명 성공`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `${successCount}명의 관리자에게 알림을 전송했습니다`,
        results 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

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