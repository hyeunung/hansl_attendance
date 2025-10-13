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
    const { inquiryId, userId, status, resolutionNote } = await req.json();

    console.log("문의 응답 알림:", { inquiryId, userId, status, resolutionNote });

    // 문의자 정보 조회
    const { data: user, error: userError } = await supabase
      .from("employees")
      .select("id, name, email, fcm_token")
      .eq("id", userId)
      .single();

    if (userError) {
      console.error("사용자 조회 실패:", userError);
      throw userError;
    }

    if (!user?.fcm_token) {
      console.log(`사용자 ${user?.name || userId}의 FCM 토큰이 없습니다.`);
      return new Response(
        JSON.stringify({
          success: false,
          message: "FCM 토큰이 없어 알림을 전송할 수 없습니다.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // 상태에 따른 알림 메시지 설정
    let title = "";
    let body = "";
    
    if (status === "resolved" || status === "closed") {
      title = "문의 답변이 도착했습니다";
      body = resolutionNote || "문의가 처리되었습니다. 앱에서 확인해주세요.";
    } else if (status === "in_progress") {
      title = "문의 처리가 시작되었습니다";
      body = "관리자가 문의를 확인하고 처리를 시작했습니다.";
    } else {
      title = "문의 상태가 변경되었습니다";
      body = `문의 상태: ${status}`;
    }

    // FCM 알림 전송
    const notificationResult = await supabase.functions.invoke("send_fcm_notification", {
      body: {
        token: user.fcm_token,
        title: title,
        body: body,
        data: {
          type: "inquiry_response",
          inquiryId: inquiryId.toString(),
          screen: "inquiry_detail",
          status: status,
          hasResponse: !!resolutionNote,
        },
      },
    });

    if (notificationResult.error) {
      console.error("FCM 전송 실패:", notificationResult.error);
      throw notificationResult.error;
    }

    console.log(`${user.name}님에게 문의 응답 알림 전송 성공`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `${user.name}님에게 알림 전송 완료`,
        notificationResult: notificationResult.data,
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