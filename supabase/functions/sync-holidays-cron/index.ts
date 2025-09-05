import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { calculateKoreanHolidays } from '../sync-holidays/lunar-converter.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Cron job으로 매년 12월에 실행하여 다음 3년치 공휴일 자동 생성
serve(async (req) => {
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Supabase 클라이언트 생성
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 현재 연도 기준으로 다음 3년치 공휴일 생성
    const currentYear = new Date().getFullYear();
    const years = [currentYear, currentYear + 1, currentYear + 2, currentYear + 3];
    
    let totalInserted = 0;
    let totalUpdated = 0;
    let totalSkipped = 0;
    const results = [];

    for (const year of years) {
      console.log(`Processing year ${year}...`);
      
      // 음력-양력 변환으로 정확한 공휴일 계산
      const holidays = calculateKoreanHolidays(year);
      
      for (const holiday of holidays) {
        // 중복 확인
        const { data: existing } = await supabase
          .from('holidays')
          .select('id, name')
          .eq('date', holiday.date)
          .single();
        
        if (existing) {
          // 이름이 다른 경우에만 업데이트
          if (existing.name !== holiday.name) {
            const { error } = await supabase
              .from('holidays')
              .update({
                name: holiday.name,
                is_alternative: holiday.is_alternative || false,
                updated_at: new Date().toISOString()
              })
              .eq('id', existing.id);
            
            if (!error) {
              totalUpdated++;
              results.push({ 
                action: 'updated', 
                year,
                date: holiday.date,
                name: holiday.name 
              });
            }
          } else {
            totalSkipped++;
          }
        } else {
          // 새로 추가
          const { error } = await supabase
            .from('holidays')
            .insert({
              date: holiday.date,
              name: holiday.name,
              is_alternative: holiday.is_alternative || false,
              year: year
            });
          
          if (!error) {
            totalInserted++;
            results.push({ 
              action: 'inserted',
              year,
              date: holiday.date,
              name: holiday.name 
            });
          }
        }
      }
    }

    // 성공 메시지와 통계
    console.log(`✅ 공휴일 자동 동기화 완료`);
    console.log(`📊 추가: ${totalInserted}개, 업데이트: ${totalUpdated}개, 건너뜀: ${totalSkipped}개`);
    console.log(`📅 처리된 연도: ${years.join(', ')}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `${currentYear}년부터 ${currentYear + 3}년까지 공휴일 자동 계산 완료`,
        summary: {
          inserted: totalInserted,
          updated: totalUpdated,
          skipped: totalSkipped,
          years: years,
          processedAt: new Date().toISOString()
        },
        results: results
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('❌ 공휴일 동기화 실패:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        processedAt: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})