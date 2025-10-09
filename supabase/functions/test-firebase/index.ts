// Test Firebase Authentication
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // 환경변수 확인
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({
        success: false,
        error: 'FIREBASE_SERVICE_ACCOUNT_JSON not found'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      });
    }

    // JSON 파싱 시도
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch (parseError) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to parse JSON',
        details: parseError.message
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      });
    }

    // 필수 필드 확인
    const requiredFields = ['project_id', 'private_key', 'client_email'];
    const missingFields = requiredFields.filter(field => !serviceAccount[field]);
    
    if (missingFields.length > 0) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing required fields',
        missing: missingFields
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      });
    }

    // private_key 형식 확인
    const hasBeginMarker = serviceAccount.private_key.includes('-----BEGIN PRIVATE KEY-----');
    const hasEndMarker = serviceAccount.private_key.includes('-----END PRIVATE KEY-----');
    
    return new Response(JSON.stringify({
      success: true,
      project_id: serviceAccount.project_id,
      client_email: serviceAccount.client_email,
      private_key_exists: !!serviceAccount.private_key,
      private_key_length: serviceAccount.private_key.length,
      has_begin_marker: hasBeginMarker,
      has_end_marker: hasEndMarker,
      environment: 'Production Edge Function'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    });
  }
});