import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // CORS 처리
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Supabase 클라이언트 생성
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 요청 바디 파싱
    const { inquiryId, userName, subject, inquiryType } = await req.json();

    console.log("새 문의 알림:", { inquiryId, userName, subject, inquiryType });

    // app_admin 권한을 가진 모든 사용자 조회
    const { data: admins, error: adminError } = await supabase
      .from("employees")
      .select("id, name, email, fcm_token")
      .contains("purchase_role", ["app_admin"]);

    if (adminError) {
      throw adminError;
    }

    console.log(`app_admin 사용자 ${admins?.length || 0}명에게 알림 전송`);

    // 각 관리자에게 푸시 알림 전송
    const notifications = [];
    for (const admin of admins || []) {
      if (!admin.fcm_token) {
        console.log(`${admin.name}님은 FCM 토큰이 없습니다.`);
        continue;
      }

      // FCM 알림 전송
      const notificationResult = await supabase.functions.invoke("send_fcm_notification", {
        body: {
          token: admin.fcm_token,
          title: "새로운 문의가 접수되었습니다",
          body: `${userName}님이 문의를 등록했습니다: ${subject}`,
          data: {
            type: "inquiry_new",
            inquiryId: inquiryId.toString(),
            screen: "inquiry_detail",
            userName: userName,
            inquiryType: inquiryType,
          },
        },
      });

      notifications.push({
        admin: admin.name,
        result: notificationResult.error ? "실패" : "성공",
        error: notificationResult.error,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `${notifications.length}명의 관리자에게 알림 전송`,
        details: notifications,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});