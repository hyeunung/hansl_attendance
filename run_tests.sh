#!/bin/bash

# HANSL 프로젝트 테스트 실행 스크립트

echo "🧪 HANSL 프로젝트 테스트 시작..."
echo "================================"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 패키지 설치
echo -e "\n${YELLOW}📦 패키지 설치 중...${NC}"
flutter pub get

# 2. 코드 분석
echo -e "\n${YELLOW}🔍 코드 분석 실행 중...${NC}"
flutter analyze
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 코드 분석 실패${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 코드 분석 통과${NC}"

# 3. 단위 테스트 실행
echo -e "\n${YELLOW}🧪 단위 테스트 실행 중...${NC}"
flutter test --coverage

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 단위 테스트 실패${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 단위 테스트 통과${NC}"

# 4. 테스트 커버리지 확인
if [ -f "coverage/lcov.info" ]; then
    echo -e "\n${YELLOW}📊 테스트 커버리지 계산 중...${NC}"
    
    # genhtml이 설치되어 있는지 확인
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html --quiet
        echo -e "${GREEN}✅ 커버리지 리포트 생성: coverage/html/index.html${NC}"
    fi
    
    # 간단한 커버리지 통계 출력
    total_lines=$(grep -c "DA:" coverage/lcov.info)
    covered_lines=$(grep "DA:" coverage/lcov.info | grep -c ",1$")
    
    if [ $total_lines -gt 0 ]; then
        coverage_percent=$((covered_lines * 100 / total_lines))
        echo -e "📈 테스트 커버리지: ${GREEN}${coverage_percent}%${NC}"
        
        if [ $coverage_percent -lt 50 ]; then
            echo -e "${YELLOW}⚠️  경고: 테스트 커버리지가 50% 미만입니다.${NC}"
        fi
    fi
fi

# 5. 통합 테스트 실행 (선택적)
echo -e "\n${YELLOW}통합 테스트를 실행하시겠습니까? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🔄 통합 테스트 실행 중...${NC}"
    flutter test integration_test/
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 통합 테스트 실패${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ 통합 테스트 통과${NC}"
fi

echo -e "\n================================"
echo -e "${GREEN}✨ 모든 테스트가 성공적으로 완료되었습니다!${NC}"
echo ""

# 테스트 결과 요약
echo "📋 테스트 결과 요약:"
echo "  • 코드 분석: ✅"
echo "  • 단위 테스트: ✅"
if [ -n "$coverage_percent" ]; then
    echo "  • 테스트 커버리지: ${coverage_percent}%"
fi
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "  • 통합 테스트: ✅"
fi

echo -e "\n💡 팁: 개별 테스트 실행 명령어"
echo "  • 특정 파일 테스트: flutter test test/utils/validators/leave_validators_test.dart"
echo "  • 위젯 테스트만: flutter test test/widgets/"
echo "  • 커버리지 리포트 열기: open coverage/html/index.html"