import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// 회사 위치 정보 (보안을 위해 서버에서 관리)
const COMPANY_LAT = 35.844541;  // hansl 위도
const COMPANY_LNG = 128.506440;  // hansl 경도
const ALLOWED_DISTANCE = 100.0;  // meters

interface LocationValidationRequest {
  latitude: number;
  longitude: number;
  employeeId: string;
  timestamp: string;
}

interface LocationValidationResponse {
  isValid: boolean;
  distance: number;
  allowedDistance: number;
  message: string;
}

// 두 지점 간의 거리 계산 (하버사인 공식)
function calculateDistance(
  lat1: number, 
  lon1: number, 
  lat2: number, 
  lon2: number
): number {
  const R = 6371000; // 지구의 반지름 (미터)
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// 좌표 유효성 검사
function isValidCoordinates(lat: number, lng: number): boolean {
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

Deno.serve(async (req: Request) => {
  // CORS 헤더 설정
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  // OPTIONS 요청 처리 (CORS preflight)
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers });
  }

  // POST 요청만 허용
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers }
    );
  }

  try {
    const requestData: LocationValidationRequest = await req.json();
    
    // 필수 필드 검증
    if (!requestData.latitude || !requestData.longitude || !requestData.employeeId) {
      return new Response(
        JSON.stringify({ 
          error: '위도, 경도, 직원 ID는 필수 항목입니다.' 
        }),
        { status: 400, headers }
      );
    }

    const { latitude, longitude, employeeId, timestamp } = requestData;

    // 좌표 유효성 검사
    if (!isValidCoordinates(latitude, longitude)) {
      return new Response(
        JSON.stringify({ 
          error: '올바르지 않은 GPS 좌표입니다.' 
        }),
        { status: 400, headers }
      );
    }

    // 시간 검증 (요청이 너무 오래된 경우 거부)
    const now = new Date();
    const requestTime = new Date(timestamp);
    const timeDiff = now.getTime() - requestTime.getTime();
    
    if (timeDiff > 30000) { // 30초 이상 차이나면 거부
      return new Response(
        JSON.stringify({ 
          error: '요청 시간이 너무 오래되었습니다.' 
        }),
        { status: 400, headers }
      );
    }

    // 거리 계산
    const distance = calculateDistance(
      latitude, 
      longitude, 
      COMPANY_LAT, 
      COMPANY_LNG
    );

    const isValid = distance <= ALLOWED_DISTANCE;

    const response: LocationValidationResponse = {
      isValid,
      distance: Math.round(distance),
      allowedDistance: ALLOWED_DISTANCE,
      message: isValid 
        ? '위치 검증 완료' 
        : `회사에서 ${Math.round(distance)}m 떨어져 있습니다. 허용 범위: ${ALLOWED_DISTANCE}m`
    };

    // 로그 기록 (보안 감사용)
    console.log({
      employeeId,
      latitude,
      longitude,
      distance: Math.round(distance),
      isValid,
      timestamp: now.toISOString()
    });

    return new Response(
      JSON.stringify(response),
      { status: 200, headers }
    );

  } catch (error) {
    console.error('Location validation error:', error);
    
    return new Response(
      JSON.stringify({ 
        error: '위치 검증 중 오류가 발생했습니다.' 
      }),
      { status: 500, headers }
    );
  }
}); 