import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    console.log('🔍 [DEBUG] Firebase 서비스 계정 JSON 분석 시작');
    
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not found');
    }
    
    const serviceAccount = JSON.parse(serviceAccountJson);
    
    console.log('✅ [DEBUG] Firebase 서비스 계정 JSON 파싱 성공');
    
    return new Response(JSON.stringify({
      success: true,
      project_id: serviceAccount.project_id,
      client_email: serviceAccount.client_email,
      private_key_exists: !!serviceAccount.private_key,
      private_key_length: serviceAccount.private_key ? serviceAccount.private_key.length : 0,
      private_key_starts_with: serviceAccount.private_key ? serviceAccount.private_key.substring(0, 50) : null,
      private_key_has_escaped_newlines: serviceAccount.private_key ? serviceAccount.private_key.includes('\\n') : false,
      private_key_has_real_newlines: serviceAccount.private_key ? serviceAccount.private_key.includes('\n') : false,
      all_keys: Object.keys(serviceAccount)
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
    
  } catch (error) {
    console.error('❌ [ERROR] Firebase 서비스 계정 JSON 분석 실패:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

