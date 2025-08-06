#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
변환된 연차 데이터를 Supabase leave 테이블에 삽입하는 스크립트
"""

import json
import os
import requests
import time
from typing import List, Dict, Any
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# Supabase 설정 (환경변수에서 가져오기)
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')

# 환경변수 검증
if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise ValueError("SUPABASE_URL과 SUPABASE_SERVICE_KEY 환경변수가 설정되지 않았습니다. .env 파일을 확인하세요.")

def check_existing_data() -> int:
    """
    기존 leave 테이블에 CSV 데이터가 이미 있는지 확인
    """
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json"
    }
    
    # CSV 데이터 이관 관련 레코드 확인
    url = f"{SUPABASE_URL}/rest/v1/leave"
    params = {
        "reason": "like.*CSV 데이터 이관*",
        "select": "count"
    }
    
    try:
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            return len(data) if isinstance(data, list) else 0
        else:
            print(f"❌ 기존 데이터 확인 실패: {response.status_code}")
            return -1
    except Exception as e:
        print(f"❌ 기존 데이터 확인 중 오류: {e}")
        return -1

def batch_insert_leave_data(records: List[Dict[str, Any]], batch_size: int = 50) -> bool:
    """
    연차 데이터를 배치로 삽입
    """
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    
    url = f"{SUPABASE_URL}/rest/v1/leave"
    
    total_records = len(records)
    successful_inserts = 0
    failed_inserts = 0
    
    print(f"📤 총 {total_records}개 레코드를 {batch_size}개씩 배치 삽입 시작...")
    
    for i in range(0, total_records, batch_size):
        batch = records[i:i + batch_size]
        batch_num = (i // batch_size) + 1
        total_batches = (total_records + batch_size - 1) // batch_size
        
        print(f"🔄 배치 {batch_num}/{total_batches} 처리 중... ({len(batch)}개 레코드)")
        
        try:
            response = requests.post(url, headers=headers, json=batch)
            
            if response.status_code in [200, 201]:
                successful_inserts += len(batch)
                print(f"✅ 배치 {batch_num} 성공: {len(batch)}개 삽입")
            else:
                failed_inserts += len(batch)
                print(f"❌ 배치 {batch_num} 실패: {response.status_code}")
                print(f"   오류 내용: {response.text}")
                
                # 개별 삽입 시도
                print("🔄 개별 삽입 재시도...")
                for record in batch:
                    try:
                        single_response = requests.post(url, headers=headers, json=[record])
                        if single_response.status_code in [200, 201]:
                            print(f"✅ {record['name']} {record['start_date']} 개별 삽입 성공")
                        else:
                            print(f"❌ {record['name']} {record['start_date']} 개별 삽입 실패")
                    except Exception as e:
                        print(f"❌ {record['name']} {record['start_date']} 개별 삽입 오류: {e}")
                        
        except Exception as e:
            failed_inserts += len(batch)
            print(f"❌ 배치 {batch_num} 예외 발생: {e}")
        
        # 서버 부하 방지를 위한 잠시 대기
        if batch_num < total_batches:
            time.sleep(0.5)
    
    print(f"\n📊 삽입 결과:")
    print(f"✅ 성공: {successful_inserts}개")
    print(f"❌ 실패: {failed_inserts}개")
    
    return failed_inserts == 0

def verify_inserted_data() -> Dict[str, Any]:
    """
    삽입된 데이터 검증
    """
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json"
    }
    
    url = f"{SUPABASE_URL}/rest/v1/leave"
    params = {
        "reason": "like.*CSV 데이터 이관*",
        "select": "name,start_date,type,status"
    }
    
    try:
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            
            # 통계 계산
            stats = {
                "total_count": len(data),
                "by_type": {},
                "by_person": {},
                "by_month": {}
            }
            
            for record in data:
                # 타입별 통계
                leave_type = record["type"]
                stats["by_type"][leave_type] = stats["by_type"].get(leave_type, 0) + 1
                
                # 사람별 통계
                name = record["name"]
                stats["by_person"][name] = stats["by_person"].get(name, 0) + 1
                
                # 월별 통계
                month = record["start_date"][5:7]
                stats["by_month"][month] = stats["by_month"].get(month, 0) + 1
            
            return stats
        else:
            print(f"❌ 검증 데이터 조회 실패: {response.status_code}")
            return {}
    except Exception as e:
        print(f"❌ 검증 중 오류: {e}")
        return {}

def main():
    """메인 실행 함수"""
    print("🚀 Supabase leave 테이블 데이터 삽입 시작...")
    print("=" * 60)
    
    # 1. 변환된 데이터 로드
    try:
        with open('converted_leave_data_fixed.json', 'r', encoding='utf-8') as f:
            records = json.load(f)
        print(f"📂 변환 데이터 로드 완료: {len(records)}개 레코드")
    except Exception as e:
        print(f"❌ 변환 데이터 로드 실패: {e}")
        return
    
    # 2. 기존 데이터 확인
    print(f"\n🔍 기존 CSV 데이터 확인...")
    existing_count = check_existing_data()
    if existing_count > 0:
        print(f"⚠️ 이미 {existing_count}개의 CSV 데이터가 존재합니다.")
        confirm = input("계속 진행하시겠습니까? (y/N): ")
        if confirm.lower() != 'y':
            print("❌ 사용자가 중단했습니다.")
            return
    elif existing_count == 0:
        print("✅ 기존 CSV 데이터 없음 - 안전하게 진행 가능")
    else:
        print("⚠️ 기존 데이터 확인 실패 - 주의해서 진행")
    
    # 3. 데이터 삽입
    print(f"\n📤 Supabase에 데이터 삽입 중...")
    success = batch_insert_leave_data(records)
    
    if success:
        print(f"\n🎉 모든 데이터 삽입 완료!")
    else:
        print(f"\n⚠️ 일부 데이터 삽입 실패")
    
    # 4. 삽입 결과 검증
    print(f"\n🔍 삽입된 데이터 검증 중...")
    stats = verify_inserted_data()
    
    if stats:
        print(f"\n📊 삽입 결과 통계:")
        print(f"✅ 총 삽입된 레코드: {stats['total_count']}개")
        
        print(f"\n📈 타입별 분포:")
        for leave_type, count in stats['by_type'].items():
            print(f"  - {leave_type}: {count}개")
        
        print(f"\n👥 상위 5명 연차 사용:")
        top_users = sorted(stats['by_person'].items(), key=lambda x: x[1], reverse=True)[:5]
        for name, count in top_users:
            print(f"  - {name}: {count}개")
        
        print(f"\n📅 월별 분포:")
        for month in sorted(stats['by_month'].keys()):
            month_name = ['', '1월', '2월', '3월', '4월', '5월', '6월', '7월'][int(month)]
            print(f"  - {month_name}: {stats['by_month'][month]}개")
        
        if stats['total_count'] == len(records):
            print(f"\n🎉 완벽! 모든 {len(records)}개 레코드가 성공적으로 삽입되었습니다!")
        else:
            print(f"\n⚠️ 불일치: 예상 {len(records)}개 vs 실제 {stats['total_count']}개")
    
    print(f"\n✅ CSV 연차 데이터 이관 완료!")

if __name__ == "__main__":
    main() 