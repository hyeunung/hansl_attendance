#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
연차 사용일 CSV → Supabase leave 테이블 변환 스크립트
"""

import csv
import json
import re
from datetime import datetime
from typing import List, Dict, Any

# 이름 → 이메일 매핑 테이블
NAME_TO_EMAIL = {
    "양승진": "ysj@hansl.com",
    "최창열": "ccy@hansl.com", 
    "김은정": "kej@hansl.com",
    "이정화": "ljh@hansl.com",
    "하치복": "hcb@hansl.com",
    "김경태": "kkt@hansl.com",
    "조근일": "cgi@hansl.com",
    "이재형": "leejh@hansl.com",
    "임소연": "lsy@hansl.com",
    "김지혜": "ji-hye.kim@hansl.com",
    "정승후": "seung-hoo.jung@hansl.com",
    "나유성": "yu-seong.na@hansl.com",
    "정현웅": "hyun-woong.jeong@hansl.com",
    "정희웅": "hee-ung.jeong@hansl.com",
    "김희승": "hee-seung.kim@hansl.com",
    "곽병현": "byeong-hyeon.kwak@hansl.com",
    "윤은호": "eun-ho.yoon@hansl.com",
    "김윤회": "yoon-whoi.kim@hansl.com",
    "석진태": "jin-tae.seok@hansl.com",
    "여도근": "do-geun.yeo@hansl.com",
    "강영은": "young-eun.kang@hansl.com",
    "이한빈": "han-bin.lee@hansl.com",
    "백현덕": "hyeon-deok.baek@hansl.com",
    "이종근": "jong-geun.lee@hansl.com",
    "이채령": "chae-ryeong.lee@hansl.com",
    "최창진": "chang-jin.choi\t@hansl.com"  # 탭 문자 포함된 상태
}

def parse_leave_dates(date_str: str, month: int) -> List[Dict[str, Any]]:
    """
    월별 연차 사용일 문자열을 파싱하여 개별 레코드로 변환
    
    Args:
        date_str: "2일, 15일(오후반차)" 같은 형태의 문자열
        month: 월 (1-12)
    
    Returns:
        List of leave records
    """
    if not date_str or date_str.strip() == "0" or date_str.strip() == "":
        return []
    
    records = []
    
    # 쉼표로 분리
    parts = date_str.split(',')
    
    for part in parts:
        part = part.strip()
        if not part:
            continue
            
        # 날짜 추출 (숫자만)
        day_match = re.search(r'(\d+)', part)
        if not day_match:
            continue
            
        day = int(day_match.group(1))
        
        # 연차 타입 결정
        if "오전" in part:
            leave_type = "half_am"
        elif "오후" in part:
            leave_type = "half_pm"
        else:
            leave_type = "annual"
            
        # 날짜 생성 (2024년 기준)
        try:
            leave_date = f"2024-{month:02d}-{day:02d}"
            
            record = {
                "date": leave_date,
                "type": leave_type
            }
            records.append(record)
            
        except ValueError as e:
            print(f"❌ 잘못된 날짜: {month}월 {day}일 - {e}")
            continue
    
    return records

def convert_csv_to_leave_records(csv_file_path: str) -> List[Dict[str, Any]]:
    """
    CSV 파일을 읽어서 leave 테이블 형태로 변환
    """
    leave_records = []
    
    with open(csv_file_path, 'r', encoding='utf-8') as file:
        reader = csv.reader(file)
        header = next(reader)  # 헤더 스킵
        
        for row in reader:
            if len(row) < 9:  # 최소 컬럼 수 체크
                continue
                
            name = row[1].strip()  # 성명
            
            if name not in NAME_TO_EMAIL:
                print(f"⚠️ 매칭되지 않은 이름: {name}")
                continue
                
            email = NAME_TO_EMAIL[name]
            
            # 1월~7월 데이터 처리
            month_data = row[2:9]  # 1월~7월 컬럼
            
            for month_idx, date_str in enumerate(month_data):
                month = month_idx + 1  # 1월부터 시작
                
                if not date_str or date_str.strip() == "":
                    continue
                    
                # 해당 월의 연차 사용일 파싱
                month_records = parse_leave_dates(date_str, month)
                
                for record in month_records:
                    leave_record = {
                        "user_email": email,
                        "name": name,
                        "type": record["type"],
                        "start_date": record["date"],
                        "end_date": record["date"],  # 단일날짜이므로 시작=종료
                        "status": "approved",  # 이미 사용한 연차
                        "reason": "2024년 상반기 연차 사용 (CSV 데이터 이관)",
                        "created_at": "2024-12-31T23:59:59+09:00"  # 임의 생성일
                    }
                    leave_records.append(leave_record)
                    
    return leave_records

def main():
    """메인 실행 함수"""
    print("🔄 CSV 연차 데이터 변환 시작...")
    
    # CSV 파일 변환
    csv_file = "연차 사용일.csv"
    leave_records = convert_csv_to_leave_records(csv_file)
    
    print(f"✅ 변환 완료: {len(leave_records)}개 레코드 생성")
    
    # 결과를 JSON 파일로 저장
    output_file = "converted_leave_data.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(leave_records, f, ensure_ascii=False, indent=2)
    
    print(f"💾 결과 저장: {output_file}")
    
    # 샘플 데이터 출력
    print("\n📋 변환 결과 샘플 (처음 5개):")
    for i, record in enumerate(leave_records[:5]):
        print(f"{i+1}. {record['name']} - {record['start_date']} ({record['type']})")
    
    # 통계 출력
    print(f"\n📊 변환 통계:")
    print(f"- 총 레코드 수: {len(leave_records)}")
    
    type_counts = {}
    for record in leave_records:
        leave_type = record['type']
        type_counts[leave_type] = type_counts.get(leave_type, 0) + 1
    
    for leave_type, count in type_counts.items():
        print(f"- {leave_type}: {count}개")

if __name__ == "__main__":
    main() 