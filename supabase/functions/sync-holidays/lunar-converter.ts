// 음력-양력 변환 로직
// 1900년부터 2100년까지의 음력 데이터

export interface LunarDate {
  year: number;
  month: number;
  day: number;
  isLeapMonth?: boolean;
}

export interface SolarDate {
  year: number;
  month: number;
  day: number;
}

// 음력 데이터 (1900-2100)
// 각 연도별 음력 월별 일수와 윤달 정보
const LUNAR_DATA = [
  0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0,
  0x09ad0, 0x055d2, 0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540,
  0x0d6a0, 0x0ada2, 0x095b0, 0x14977, 0x04970, 0x0a4b0, 0x0b4b5, 0x06a50,
  0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, 0x06566, 0x0d4a0,
  0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
  0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2,
  0x0a950, 0x0b557, 0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5d0, 0x14573,
  0x052d0, 0x0a9a8, 0x0e950, 0x06aa0, 0x0aea6, 0x0ab50, 0x04b60, 0x0aae4,
  0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, 0x096d0, 0x04dd5,
  0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b5a0, 0x195a6,
  0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46,
  0x0ab60, 0x09570, 0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58,
  0x055c0, 0x0ab60, 0x096d5, 0x092e0, 0x0c960, 0x0d954, 0x0d4a0, 0x0da50,
  0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, 0x0a950, 0x0b4a0,
  0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
  0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260,
  0x0ea65, 0x0d530, 0x05aa0, 0x076a3, 0x096d0, 0x04bd7, 0x04ad0, 0x0a4d0,
  0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, 0x0b5a0, 0x056d0, 0x055b2, 0x049b0,
  0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0
];

// 음력 날짜를 양력으로 변환
export function lunarToSolar(lunar: LunarDate): SolarDate {
  const baseDate = new Date(1900, 0, 31); // 1900년 1월 31일이 음력 1900년 1월 1일
  let offset = 0;
  
  // 1900년부터 해당 연도까지의 일수 계산
  for (let i = 1900; i < lunar.year; i++) {
    offset += getLunarYearDays(i);
  }
  
  // 해당 연도의 월별 일수 더하기
  let leapMonth = getLeapMonth(lunar.year);
  let isLeap = false;
  
  for (let i = 1; i < lunar.month; i++) {
    if (i === leapMonth) {
      offset += getLeapMonthDays(lunar.year);
      isLeap = true;
    }
    offset += getLunarMonthDays(lunar.year, i);
  }
  
  // 윤달 처리
  if (lunar.isLeapMonth && leapMonth === lunar.month) {
    offset += getLunarMonthDays(lunar.year, lunar.month);
  }
  
  // 일수 더하기
  offset += lunar.day - 1;
  
  // 기준일에서 offset만큼 더하기
  const result = new Date(baseDate.getTime() + offset * 24 * 60 * 60 * 1000);
  
  return {
    year: result.getFullYear(),
    month: result.getMonth() + 1,
    day: result.getDate()
  };
}

// 연도의 총 일수
function getLunarYearDays(year: number): number {
  let sum = 348;
  const data = LUNAR_DATA[year - 1900];
  
  for (let i = 0x8000; i > 0x8; i >>= 1) {
    sum += (data & i) ? 1 : 0;
  }
  
  return sum + getLeapMonthDays(year);
}

// 윤달의 일수
function getLeapMonthDays(year: number): number {
  const leapMonth = getLeapMonth(year);
  if (leapMonth === 0) return 0;
  
  const data = LUNAR_DATA[year - 1900];
  return (data & 0x10000) ? 30 : 29;
}

// 윤달이 있는 월
function getLeapMonth(year: number): number {
  return LUNAR_DATA[year - 1900] & 0xf;
}

// 특정 월의 일수
function getLunarMonthDays(year: number, month: number): number {
  const data = LUNAR_DATA[year - 1900];
  return (data & (0x10000 >> month)) ? 30 : 29;
}

// 한국 공휴일 계산 함수
export function calculateKoreanHolidays(year: number) {
  const holidays = [];
  
  // 1. 양력 고정 공휴일
  holidays.push(
    { date: `${year}-01-01`, name: '신정', lunar: false },
    { date: `${year}-03-01`, name: '삼일절', lunar: false },
    { date: `${year}-05-05`, name: '어린이날', lunar: false },
    { date: `${year}-06-06`, name: '현충일', lunar: false },
    { date: `${year}-08-15`, name: '광복절', lunar: false },
    { date: `${year}-10-03`, name: '개천절', lunar: false },
    { date: `${year}-10-09`, name: '한글날', lunar: false },
    { date: `${year}-12-25`, name: '크리스마스', lunar: false }
  );
  
  // 2. 음력 공휴일 (양력으로 변환)
  // 설날 (음력 1월 1일)
  const lunarNewYear = lunarToSolar({ year, month: 1, day: 1 });
  const lunarNewYearDate = `${lunarNewYear.year}-${String(lunarNewYear.month).padStart(2, '0')}-${String(lunarNewYear.day).padStart(2, '0')}`;
  
  holidays.push(
    { 
      date: addDays(lunarNewYearDate, -1), 
      name: '설날 연휴',
      lunar: true 
    },
    { 
      date: lunarNewYearDate, 
      name: '설날',
      lunar: true 
    },
    { 
      date: addDays(lunarNewYearDate, 1), 
      name: '설날 연휴',
      lunar: true 
    }
  );
  
  // 부처님오신날 (음력 4월 8일)
  const buddhaBirthday = lunarToSolar({ year, month: 4, day: 8 });
  holidays.push({
    date: `${buddhaBirthday.year}-${String(buddhaBirthday.month).padStart(2, '0')}-${String(buddhaBirthday.day).padStart(2, '0')}`,
    name: '부처님오신날',
    lunar: true
  });
  
  // 추석 (음력 8월 15일)
  const chuseok = lunarToSolar({ year, month: 8, day: 15 });
  const chuseokDate = `${chuseok.year}-${String(chuseok.month).padStart(2, '0')}-${String(chuseok.day).padStart(2, '0')}`;
  
  holidays.push(
    { 
      date: addDays(chuseokDate, -1), 
      name: '추석 연휴',
      lunar: true 
    },
    { 
      date: chuseokDate, 
      name: '추석',
      lunar: true 
    },
    { 
      date: addDays(chuseokDate, 1), 
      name: '추석 연휴',
      lunar: true 
    }
  );
  
  // 3. 대체공휴일 계산
  holidays.forEach(holiday => {
    const date = new Date(holiday.date);
    const dayOfWeek = date.getDay(); // 0: 일요일, 6: 토요일
    
    // 설날, 추석이 주말과 겹치면 대체공휴일
    if ((holiday.name === '설날' || holiday.name === '추석') && (dayOfWeek === 0 || dayOfWeek === 6)) {
      // 다음 평일을 대체공휴일로
      let substituteDate = new Date(date);
      while (substituteDate.getDay() === 0 || substituteDate.getDay() === 6) {
        substituteDate.setDate(substituteDate.getDate() + 1);
      }
      
      holidays.push({
        date: substituteDate.toISOString().split('T')[0],
        name: `${holiday.name} 대체공휴일`,
        is_alternative: true
      });
    }
    
    // 어린이날이 토요일/일요일이면 대체공휴일
    if (holiday.name === '어린이날' && (dayOfWeek === 0 || dayOfWeek === 6)) {
      const nextMonday = new Date(date);
      nextMonday.setDate(date.getDate() + ((8 - dayOfWeek) % 7));
      
      holidays.push({
        date: nextMonday.toISOString().split('T')[0],
        name: '어린이날 대체공휴일',
        is_alternative: true
      });
    }
  });
  
  // 날짜순 정렬
  holidays.sort((a, b) => a.date.localeCompare(b.date));
  
  return holidays;
}

function addDays(dateStr: string, days: number): string {
  const date = new Date(dateStr);
  date.setDate(date.getDate() + days);
  return date.toISOString().split('T')[0];
}