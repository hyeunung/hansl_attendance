import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // 사용자 정보 확인
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      throw new Error('Unauthorized')
    }

    // 사용자 정보 가져오기
    const { data: employee, error: employeeError } = await supabase
      .from('employees')
      .select('name, email, roles')
      .eq('id', user.id)
      .single()

    if (employeeError || !employee) {
      throw new Error('Employee not found')
    }

    // 권한 확인
    const roles = employee.roles || []
    const hasPermission = roles.includes('superadmin') ||
                          roles.includes('lead_buyer')

    // 요청 데이터 파싱
    const { itemId, requestId } = await req.json()
    
    if (!itemId) {
      throw new Error('Item ID is required')
    }

    // 요청자 본인인지 확인 (권한이 없는 경우)
    if (!hasPermission && requestId) {
      const { data: request, error: requestError } = await supabase
        .from('purchase_requests')
        .select('requester_email')
        .eq('id', requestId)
        .single()

      if (requestError || !request) {
        throw new Error('Purchase request not found')
      }

      if (request.requester_email !== employee.email) {
        throw new Error('Permission denied')
      }
    }

    // 품목 입고 완료 처리
    const { data, error } = await supabase.rpc('mark_item_as_received', {
      p_item_id: itemId,
      p_user_name: employee.name
    })

    if (error) {
      console.error('Error marking item as received:', error)
      throw error
    }

    // 업데이트된 품목 정보 반환
    const { data: updatedItem, error: fetchError } = await supabase
      .from('purchase_request_items')
      .select('*')
      .eq('id', itemId)
      .single()

    if (fetchError) {
      console.error('Error fetching updated item:', fetchError)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: '품목이 입고 완료 처리되었습니다',
        item: updatedItem 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error in mark-item-as-received:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || 'Internal server error' 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: error.message === 'Unauthorized' ? 401 : 
                error.message === 'Permission denied' ? 403 : 400,
      }
    )
  }
})