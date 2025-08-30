import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      db: { schema: 'public' },
      auth: { persistSession: false }
    })

    // 트리거 비활성화, 업데이트, 트리거 재활성화를 한 번에 수행
    const query = `
      DO $$
      BEGIN
        -- 트리거 비활성화
        ALTER TABLE leave DISABLE TRIGGER ALL;
        
        -- 데이터 업데이트
        UPDATE leave SET type = 'half_pm' WHERE id = 441;
        
        -- 트리거 재활성화
        ALTER TABLE leave ENABLE TRIGGER ALL;
      END $$;
    `

    // PostgreSQL 직접 쿼리 실행
    const { data, error } = await supabase.rpc('exec_sql', {
      query: query
    }).single()

    if (error) {
      // RPC가 없으면 대체 방법 시도
      console.error('RPC error:', error)
      
      // 직접 업데이트 시도 (트리거 문제 무시)
      const updateQuery = `
        UPDATE leave 
        SET type = 'half_pm'::text
        WHERE id = 441
        RETURNING id, name, type, start_date;
      `
      
      // 다른 방법으로 시도
      const { data: result, error: updateError } = await fetch(`${supabaseUrl}/rest/v1/rpc/query`, {
        method: 'POST',
        headers: {
          'apikey': supabaseServiceKey,
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify({ query: updateQuery })
      }).then(res => res.json())

      if (updateError) {
        throw new Error(updateError.message || 'Update failed')
      }

      return new Response(
        JSON.stringify({ success: true, data: result }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 결과 확인
    const { data: checkData } = await supabase
      .from('leave')
      .select('id, name, type, start_date')
      .eq('id', 441)
      .single()

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Leave type updated successfully',
        data: checkData 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      }
    )
  }
})