import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// 근무 시간 설정 (회사 규정)
const WORK_START_TIME = { hour: 8, minute: 30 }; // 08:30
const WORK_END_TIME = { hour: 18, minute: 0 };   // 18:00

interface WorkTimeValidationRequest {
  employeeId: string;
  action: 'clockIn' | 'clockOut';
  clientTime: string; // 클라이언트가 보낸 시간 (비교용)
}

interface WorkTimeValidationResponse {
  isValid: boolean;
  serverTime: string;
  isLate: boolean;
  message: string;
  workHours?: {
    start: string;
    end: string;
  };
}

// 시간을 HH:MM:SS 형식으로 포맷
function formatTime(date: Date): string {
  return date.toTimeString().substring(0, 8);
}

// 날짜를 YYYY-MM-DD 형식으로 포맷
function formatDate(date: Date): string {
  return date.toISOString().substring(0, 10);
}

// 지각 여부 확인
function isLateArrival(serverTime: Date): boolean {
  const hour = serverTime.getHours();
  const minute = serverTime.getMinutes();
  
  if (hour > WORK_START_TIME.hour) {
    return true;
  } else if (hour === WORK_START_TIME.hour && minute > WORK_START_TIME.minute) {
    return true;
  }
  return false;
}

// 출근 시간 유효성 검사 (너무 이른 시간 또는 너무 늦은 시간 방지)
function isValidClockInTime(serverTime: Date): boolean {
  const hour = serverTime.getHours();
  // 새벽 6시 이전이나 오후 6시 이후 출근 불가
  return hour >= 6 && hour < 18;
}

// 퇴근 시간 유효성 검사
function isValidClockOutTime(serverTime: Date): boolean {
  const hour = serverTime.getHours();
  // 오전 8시 이전이나 밤 11시 이후 퇴근 불가
  return hour >= 8 && hour < 23;
}

Deno.serve(async (req: Request) => {
  // CORS 헤더 설정
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers }
    );
  }

  try {
    const requestData: WorkTimeValidationRequest = await req.json();
    
    // 필수 필드 검증
    if (!requestData.employeeId || !requestData.action) {
      return new Response(
        JSON.stringify({ 
          error: '직원 ID와 액션은 필수 항목입니다.' 
        }),
        { status: 400, headers }
      );
    }

    const { employeeId, action, clientTime } = requestData;
    
    // 서버 시간 획득 (UTC 기준)
    const utcTime = new Date();
    
    // 한국 시간으로 변환 (UTC+9)
    const koreaTime = new Date(utcTime.toLocaleString("en-US", {timeZone: "Asia/Seoul"}));
    
    let isValid = true;
    let message = '';
    let isLate = false;

    if (action === 'clockIn') {
      // 출근 시간 검증
      isValid = isValidClockInTime(koreaTime);
      isLate = isLateArrival(koreaTime);
      
      if (!isValid) {
        message = '출근 가능한 시간이 아닙니다. (06:00 ~ 18:00)';
      } else if (isLate) {
        message = `지각입니다. 출근 시간: ${WORK_START_TIME.hour.toString().padStart(2, '0')}:${WORK_START_TIME.minute.toString().padStart(2, '0')}`;
      } else {
        message = '정상 출근입니다.';
      }
    } else if (action === 'clockOut') {
      // 퇴근 시간 검증
      isValid = isValidClockOutTime(koreaTime);
      
      if (!isValid) {
        message = '퇴근 가능한 시간이 아닙니다. (08:00 ~ 23:00)';
      } else {
        message = '퇴근 처리되었습니다.';
      }
    }

    const response: WorkTimeValidationResponse = {
      isValid,
      serverTime: koreaTime.toISOString(),
      isLate,
      message,
      workHours: {
        start: `${WORK_START_TIME.hour.toString().padStart(2, '0')}:${WORK_START_TIME.minute.toString().padStart(2, '0')}`,
        end: `${WORK_END_TIME.hour.toString().padStart(2, '0')}:${WORK_END_TIME.minute.toString().padStart(2, '0')}`
      }
    };

    // 로그 기록 (시간 조작 감지용)
    const clientTimeObj = clientTime ? new Date(clientTime) : null;
    const timeDiff = clientTimeObj ? Math.abs(koreaTime.getTime() - clientTimeObj.getTime()) : 0;
    
    console.log({
      employeeId,
      action,
      serverTime: koreaTime.toISOString(),
      clientTime,
      timeDifference: timeDiff,
      isLate,
      isValid,
      suspiciousTimeDiff: timeDiff > 60000 // 1분 이상 차이나면 의심스러운 상황
    });

    return new Response(
      JSON.stringify(response),
      { status: 200, headers }
    );

  } catch (error) {
    console.error('Work time validation error:', error);
    
    return new Response(
      JSON.stringify({ 
        error: '근무 시간 검증 중 오류가 발생했습니다.' 
      }),
      { status: 500, headers }
    );
  }
}); 