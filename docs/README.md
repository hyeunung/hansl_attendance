# 📚 Documentation

이 폴더에는 연차 시스템 개발 및 정리 과정에서 생성된 문서들이 포함되어 있습니다.

## 📋 **문서 목록**

### **아키텍처 문서**
- `ANNUAL_LEAVE_ARCHITECTURE.md` - 연차 시스템 아키텍처 정리
- `CLEANUP_REPORT.md` - 연차 시스템 중복 로직 완전 정리 보고서
- `DUPLICATE_LOGIC_CLEANUP.md` - 중복 로직 제거 완료 보고서

### **Edge Functions 문서**  
- `supabase/functions/calculate_annual_leave/DEPRECATED.md` - calculate_annual_leave 함수 DEPRECATED 안내
- `supabase/functions/fix_new_hire_annual_leave/DEPRECATED.md` - fix_new_hire_annual_leave 함수 DEPRECATED 안내

## 🎯 **현재 시스템 상태**

✅ **완료된 요구사항**
1. 지급연차: 년도별, 직원별 백엔드로 계산 후 DB에 기록
2. 사용연차: 각 직원 년도별 사용 연차 계산후 DB에 기록  
3. 잔여연차: DB에서 지급연차 - 사용연차
4. 대시보드: 잔여연차를 DB에서 직접 표시
5. 설정화면: 총연차/소모연차/잔여연차를 DB에서 직접 표시
6. 중복 제거: 모든 중복 로직 제거 및 인터페이스 유지

✅ **보안 강화**
- 모든 Edge Function에 인증 로직 추가
- 권한별 접근 제어 완료

## 🔄 **데이터 흐름**
```
연차 신청/승인 → update_used_annual_leave → DB 업데이트 → 프론트엔드 로드 → UI 표시
```

## 🛡️ **활성 Edge Functions**
- `update_used_annual_leave` - 사용연차 + 잔여연차 계산 전담
- `anniversary_check` - 입사 기념일 연차 15개 지급 (관리자만)
- (Edge Function 없음) 새해 전체 직원 연차 초기화는 DB 함수 `public.run_annual_year_update(_kst)` + pg_cron으로 처리

## 🚫 **비활성화된 Functions**
- `calculate_annual_leave` - DEPRECATED (410 Gone)
- `fix_new_hire_annual_leave` - DEPRECATED (410 Gone)