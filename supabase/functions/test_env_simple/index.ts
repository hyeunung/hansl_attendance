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
    console.log('🔍 [DEBUG] 환경변수 확인 시작');
    
    // 모든 환경변수 확인
    const envVars = Deno.env.toObject();
    const firebaseVars = {};
    const supabaseVars = {};
    
    for (const [key, value] of Object.entries(envVars)) {
      if (key.includes('FIREBASE')) {
        firebaseVars[key] = value ? `설정됨 (길이: ${value.length})` : '없음';
      }
      if (key.includes('SUPABASE')) {
        supabaseVars[key] = value ? `설정됨 (길이: ${value.length})` : '없음';
      }
    }
    
    console.log('✅ [DEBUG] 환경변수 확인 완료');
    
    return new Response(JSON.stringify({
      success: true,
      firebase: firebaseVars,
      supabase: supabaseVars,
      totalEnvVars: Object.keys(envVars).length
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
    
  } catch (error) {
    console.error('❌ [ERROR] 환경변수 확인 실패:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

