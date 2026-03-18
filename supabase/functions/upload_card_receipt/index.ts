import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 인증된 사용자 확인
    const authHeader = req.headers.get('authorization')
    if (!authHeader) {
      throw new Error('인증 헤더가 없습니다.')
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      throw new Error('인증 실패')
    }

    // multipart/form-data 파싱
    const formData = await req.formData()
    const file = formData.get('file') as File
    const cardUsageId = formData.get('card_usage_id') as string
    const merchantName = formData.get('merchant_name') as string
    const itemName = formData.get('item_name') as string
    const totalAmount = formData.get('total_amount') as string
    const remark = formData.get('remark') as string | null

    if (!file || !cardUsageId || !merchantName || !itemName || !totalAmount) {
      throw new Error('필수 파라미터가 누락되었습니다.')
    }

    // 파일 확장자 추출
    const ext = file.name.split('.').pop() || 'jpg'
    const timestamp = Date.now()
    const filePath = `card-usage/${cardUsageId}/${timestamp}.${ext}`

    // Storage에 업로드
    const fileBuffer = await file.arrayBuffer()
    const { error: uploadError } = await supabase.storage
      .from('card-receipts')
      .upload(filePath, fileBuffer, {
        contentType: file.type || 'image/jpeg',
        upsert: false
      })

    if (uploadError) {
      console.error('파일 업로드 실패:', uploadError)
      throw new Error('파일 업로드에 실패했습니다.')
    }

    // 공개 URL 생성
    const { data: urlData } = supabase.storage
      .from('card-receipts')
      .getPublicUrl(filePath)

    const receiptUrl = urlData.publicUrl

    // card_usage_receipts 테이블에 INSERT
    const { data: receiptData, error: insertError } = await supabase
      .from('card_usage_receipts')
      .insert({
        card_usage_id: parseInt(cardUsageId),
        receipt_url: receiptUrl,
        merchant_name: merchantName,
        item_name: itemName,
        total_amount: parseFloat(totalAmount),
        remark: remark || null
      })
      .select()
      .single()

    if (insertError) {
      console.error('영수증 메타데이터 저장 실패:', insertError)
      throw new Error('영수증 정보 저장에 실패했습니다.')
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: receiptData,
        receipt_url: receiptUrl
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})
