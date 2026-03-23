import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
    // Service role client for admin operations
    const supabaseServiceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // User client for authentication check (using service key)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get authenticated user
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      throw new Error('인증되지 않은 사용자입니다')
    }

    // Get request body
    const { purchaseOrderNumber, purchaseDate, notes } = await req.json()

    if (!purchaseOrderNumber) {
      throw new Error('발주번호가 필요합니다')
    }

    // Check user's purchase role using service client
    const { data: employee, error: employeeError } = await supabaseServiceClient
      .from('employees')
      .select('roles')
      .eq('email', user.email)
      .single()

    if (employeeError || !employee) {
      throw new Error('직원 정보를 찾을 수 없습니다')
    }

    // Verify permission: must have 'lead_buyer' or 'superadmin' role
    const roles = employee.roles || []
    const hasPermission = roles.includes('lead_buyer') ||
                          roles.includes('superadmin')

    if (!hasPermission) {
      throw new Error('구매 완료 처리 권한이 없습니다')
    }

    // Update purchase_requests table using service client
    const { error: updateError } = await supabaseServiceClient
      .from('purchase_requests')
      .update({
        is_payment_completed: true,
        payment_completed_at: purchaseDate || new Date().toISOString(),
      })
      .eq('purchase_order_number', purchaseOrderNumber)

    if (updateError) {
      throw updateError
    }

    // Log the action for audit trail (optional)
    // Commented out as audit_logs table might not exist
    // const { error: logError } = await supabaseClient
    //   .from('audit_logs')
    //   .insert({
    //     user_email: user.email,
    //     action: 'mark_as_purchased',
    //     target_type: 'purchase_request',
    //     target_id: purchaseOrderNumber,
    //     details: {
    //       purchase_date: purchaseDate,
    //       notes: notes,
    //     },
    //     created_at: new Date().toISOString(),
    //   })

    // // Log error is non-critical, so we don't throw
    // if (logError) {
    //   console.error('Failed to create audit log:', logError)
    // }

    return new Response(
      JSON.stringify({
        success: true,
        message: '구매 완료 처리되었습니다',
        purchaseOrderNumber,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})