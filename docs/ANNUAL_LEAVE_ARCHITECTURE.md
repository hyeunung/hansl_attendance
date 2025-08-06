# 연차 시스템 아키텍처 정리

## 🎯 **함수별 역할 분담**

### **1. 지급연차 계산 (calculate_annual_leave)**
- **역할**: 직원별 지급연차만 계산 및 업데이트
- **업데이트 컬럼**: `annual_leave_granted_current_year`
- **호출 시점**: 
  - 입사 기념일
  - 년차 승급 시
  - 연차 정책 변경 시

### **2. 사용연차 계산 (update_used_annual_leave)**  
- **역할**: 사용연차 계산 및 잔여연차 자동 계산
- **업데이트 컬럼**: `used_annual_leave_current_year`, `remaining_annual_leave`
- **공식**: `잔여연차 = 지급연차 - 사용연차`
- **호출 시점**:
  - 연차 신청 완료 시
  - 연차 승인/반려 시
  - 정기 배치 업데이트

### **3. 년도별 연차 업데이트 (annual_year_update)**
- **역할**: 새 년도 시작 시 전체 직원 연차 초기화
- **업데이트 컬럼**: `annual_leave_granted_current_year`, `used_annual_leave_current_year`, `remaining_annual_leave`
- **초기값**: 지급연차 = 계산값, 사용연차 = 0, 잔여연차 = 지급연차

### **4. 입사 기념일 처리 (anniversary_check)**
- **역할**: 입사 12개월 완성 시 연차 15개 지급
- **업데이트 컬럼**: `annual_leave_granted_current_year`, `remaining_annual_leave`

## 🚫 **제거된 중복 로직**

1. ❌ `calculate_annual_leave`에서 사용연차 계산 제거
2. ❌ `fetchMyLeaves`에서 이중 함수 호출 제거  
3. ❌ 여러 곳에서 동일한 잔여연차 계산 로직 통합

## ✅ **데이터 일관성 보장**

- **단일 책임 원칙**: 각 함수는 하나의 역할만 담당
- **중복 제거**: 사용연차 계산은 `update_used_annual_leave`에서만
- **자동 동기화**: 사용연차 업데이트 시 잔여연차 자동 계산

## 🔄 **호출 순서**

```
연차 신청 → update_used_annual_leave → DB 업데이트 → 프론트엔드 새로고침
연차 승인 → update_used_annual_leave → DB 업데이트 → 프론트엔드 새로고침
새 년도   → annual_year_update → 전체 초기화 → 개별 update_used_annual_leave
```