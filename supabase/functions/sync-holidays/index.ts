import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { calculateKoreanHolidays } from './lunar-converter.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 한국 공휴일 API 자동 연동
async function fetchKoreanHolidaysFromAPI(year: number) {
  try {
    // 1. 공공데이터포털 API (data.go.kr)
    const DATA_GO_KR_KEY = Deno.env.get('DATA_GO_KR_API_KEY');
    if (DATA_GO_KR_KEY) {
      const url = `http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo?` +
        `serviceKey=${DATA_GO_KR_KEY}&` +
        `solYear=${year}&` +
        `_type=json`;
      
      const response = await fetch(url);
      if (response.ok) {
        const data = await response.json();
        const items = data.response?.body?.items?.item || [];
        return items.map((item: any) => ({
          date: `${year}-${String(item.locdate).slice(4,6)}-${String(item.locdate).slice(6,8)}`,
          name: item.dateName,
          is_alternative: item.isHoliday === 'N'
        }));
      }
    }
    
    // 2. Google Calendar API (무료 대안)
    const GOOGLE_API_KEY = Deno.env.get('GOOGLE_CALENDAR_API_KEY');
    if (GOOGLE_API_KEY) {
      const CALENDAR_ID = 'ko.south_korea#holiday@group.v.calendar.google.com';
      const url = `https://www.googleapis.com/calendar/v3/calendars/${CALENDAR_ID}/events?` +
        `key=${GOOGLE_API_KEY}&` +
        `timeMin=${year}-01-01T00:00:00Z&` +
        `timeMax=${year}-12-31T23:59:59Z&` +
        `singleEvents=true&` +
        `orderBy=startTime`;
      
      const response = await fetch(url);
      if (response.ok) {
        const data = await response.json();
        return data.items?.map((item: any) => ({
          date: item.start.date,
          name: item.summary,
          is_alternative: item.summary.includes('대체')
        })) || [];
      }
    }
    
    // 3. 음력 계산 + 고정 공휴일 (API 없을 때)
    const holidays = [];
    
    // 고정 공휴일
    holidays.push(
      { date: `${year}-01-01`, name: '신정' },
      { date: `${year}-03-01`, name: '삼일절' },
      { date: `${year}-05-05`, name: '어린이날' },
      { date: `${year}-06-06`, name: '현충일' },
      { date: `${year}-08-15`, name: '광복절' },
      { date: `${year}-10-03`, name: '개천절' },
      { date: `${year}-10-09`, name: '한글날' },
      { date: `${year}-12-25`, name: '크리스마스' }
    );
    
    // 설날/추석은 음력 계산 필요 (간단한 추정)
    // 실제로는 음력 변환 라이브러리 필요
    const lunarNewYear = calculateLunarNewYear(year);
    const chuseok = calculateChuseok(year);
    
    holidays.push(
      { date: addDays(lunarNewYear, -1), name: '설날 연휴' },
      { date: lunarNewYear, name: '설날' },
      { date: addDays(lunarNewYear, 1), name: '설날 연휴' },
      { date: addDays(chuseok, -1), name: '추석 연휴' },
      { date: chuseok, name: '추석' },
      { date: addDays(chuseok, 1), name: '추석 연휴' }
    );
    
    return holidays;
    
  } catch (error) {
    console.error('API 호출 실패:', error);
    return getHardcodedHolidays(year);
  }
}

// 음력 날짜 계산 헬퍼 (간단한 추정)
function calculateLunarNewYear(year: number): string {
  // 실제로는 정확한 음력 변환 필요
  const estimates: { [key: number]: string } = {
    2028: '2028-01-26',
    2029: '2029-02-13',
    2030: '2030-02-03'
  };
  return estimates[year] || `${year}-01-28`;
}

function calculateChuseok(year: number): string {
  const estimates: { [key: number]: string } = {
    2028: '2028-10-03',
    2029: '2029-09-22',
    2030: '2030-09-12'
  };
  return estimates[year] || `${year}-09-15`;
}

function addDays(dateStr: string, days: number): string {
  const date = new Date(dateStr);
  date.setDate(date.getDate() + days);
  return date.toISOString().split('T')[0];
}

// 하드코딩된 공휴일 데이터 (fallback)
function getHardcodedHolidays(year: number) {
  const holidays: { [key: number]: any[] } = {
    2025: [
      { date: '2025-01-01', name: '신정' },
      { date: '2025-01-28', name: '설날 연휴' },
      { date: '2025-01-29', name: '설날' },
      { date: '2025-01-30', name: '설날 연휴' },
      { date: '2025-03-01', name: '삼일절' },
      { date: '2025-05-05', name: '어린이날' },
      { date: '2025-05-06', name: '어린이날 대체공휴일', is_alternative: true },
      { date: '2025-06-06', name: '현충일' },
      { date: '2025-08-15', name: '광복절' },
      { date: '2025-10-03', name: '개천절' },
      { date: '2025-10-05', name: '추석 연휴' },
      { date: '2025-10-06', name: '추석' },
      { date: '2025-10-07', name: '추석 연휴' },
      { date: '2025-10-08', name: '추석 대체공휴일', is_alternative: true },
      { date: '2025-10-09', name: '한글날' },
      { date: '2025-12-25', name: '크리스마스' }
    ],
    2026: [
      { date: '2026-01-01', name: '신정' },
      { date: '2026-02-16', name: '설날 연휴' },
      { date: '2026-02-17', name: '설날' },
      { date: '2026-02-18', name: '설날 연휴' },
      { date: '2026-03-01', name: '삼일절' },
      { date: '2026-03-02', name: '삼일절 대체공휴일', is_alternative: true },
      { date: '2026-05-05', name: '어린이날' },
      { date: '2026-06-06', name: '현충일' },
      { date: '2026-08-15', name: '광복절' },
      { date: '2026-09-24', name: '추석 연휴' },
      { date: '2026-09-25', name: '추석' },
      { date: '2026-09-26', name: '추석 연휴' },
      { date: '2026-09-28', name: '추석 대체공휴일', is_alternative: true },
      { date: '2026-10-03', name: '개천절' },
      { date: '2026-10-09', name: '한글날' },
      { date: '2026-12-25', name: '크리스마스' }
    ],
    2027: [
      { date: '2027-01-01', name: '신정' },
      { date: '2027-02-06', name: '설날 연휴' },
      { date: '2027-02-07', name: '설날' },
      { date: '2027-02-08', name: '설날 연휴' },
      { date: '2027-02-09', name: '설날 대체공휴일', is_alternative: true },
      { date: '2027-03-01', name: '삼일절' },
      { date: '2027-05-05', name: '어린이날' },
      { date: '2027-06-06', name: '현충일' },
      { date: '2027-06-07', name: '현충일 대체공휴일', is_alternative: true },
      { date: '2027-08-15', name: '광복절' },
      { date: '2027-08-16', name: '광복절 대체공휴일', is_alternative: true },
      { date: '2027-09-14', name: '추석 연휴' },
      { date: '2027-09-15', name: '추석' },
      { date: '2027-09-16', name: '추석 연휴' },
      { date: '2027-10-03', name: '개천절' },
      { date: '2027-10-04', name: '개천절 대체공휴일', is_alternative: true },
      { date: '2027-10-09', name: '한글날' },
      { date: '2027-12-25', name: '크리스마스' }
    ]
  };
  
  // 미래 연도는 Google Calendar API에서 가져오거나, 
  // 없으면 기본 공휴일만 반환
  if (year > 2027) {
    // 기본 공휴일 (매년 고정)
    return [
      { date: `${year}-01-01`, name: '신정' },
      { date: `${year}-03-01`, name: '삼일절' },
      { date: `${year}-05-05`, name: '어린이날' },
      { date: `${year}-06-06`, name: '현충일' },
      { date: `${year}-08-15`, name: '광복절' },
      { date: `${year}-10-03`, name: '개천절' },
      { date: `${year}-10-09`, name: '한글날' },
      { date: `${year}-12-25`, name: '크리스마스' }
      // 설날, 추석은 음력이라 계산 필요
    ];
  }
  
  return holidays[year] || [];
}

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

    // 현재 연도와 다음 연도의 공휴일 동기화
    const currentYear = new Date().getFullYear();
    const years = [currentYear, currentYear + 1, currentYear + 2]; // 3년치 미리 계산
    
    let totalInserted = 0;
    let totalUpdated = 0;
    let totalSkipped = 0;
    const results = [];

    for (const year of years) {
      
      // 음력-양력 변환으로 공휴일 계산
      const holidays = calculateKoreanHolidays(year);
      
      for (const holiday of holidays) {
        // 중복 확인
        const { data: existing } = await supabase
          .from('holidays')
          .select('id')
          .eq('date', holiday.date)
          .single();
        
        if (existing) {
          // 업데이트 (이름이 변경될 수 있음)
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
            results.push({ action: 'updated', ...holiday });
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
            results.push({ action: 'inserted', ...holiday });
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: '공휴일 동기화 완료',
        summary: {
          inserted: totalInserted,
          updated: totalUpdated,
          skipped: totalSkipped,
          years: years
        },
        results: results
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})