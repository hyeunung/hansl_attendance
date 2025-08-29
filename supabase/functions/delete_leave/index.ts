import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    // Service Role 키를 사용하여 RLS를 우회
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 요청 본문 파싱
    const { leaveId, userEmail, isAdmin } = await req.json();

    if (!leaveId) {
      throw new Error('leaveId is required');
    }

    console.log('Delete request:', { leaveId, userEmail, isAdmin });

    let deleteQuery = supabase
      .from('leave')
      .delete()
      .eq('id', leaveId);

    // 관리자가 아닌 경우, 본인의 pending 상태만 삭제 가능
    if (!isAdmin) {
      if (!userEmail) {
        throw new Error('userEmail is required for non-admin users');
      }
      deleteQuery = deleteQuery
        .eq('user_email', userEmail)
        .eq('status', 'pending');
    }

    // select()를 추가하여 삭제된 행을 반환
    const { data: deletedData, error } = await deleteQuery.select();

    if (error) {
      console.error('Delete error:', error);
      throw error;
    }

    if (!deletedData || deletedData.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: '삭제할 수 없는 항목이거나 이미 삭제되었습니다.' 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404 
        }
      );
    }

    console.log('Successfully deleted:', deletedData);

    return new Response(
      JSON.stringify({ 
        success: true, 
        deleted: deletedData,
        message: `${deletedData.length}개 항목이 삭제되었습니다.`
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    );
  }
});