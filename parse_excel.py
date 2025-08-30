#!/usr/bin/env python3
import sys
import subprocess

# Try to import required libraries
try:
    import pandas as pd
    import openpyxl
except ImportError:
    print("필요한 라이브러리를 설치합니다...")
    subprocess.run([sys.executable, "-m", "pip", "install", "--user", "pandas", "openpyxl"], check=True)
    import pandas as pd
    import openpyxl

import json
from datetime import datetime

def parse_excel():
    try:
        # 엑셀 파일 읽기
        df = pd.read_excel('78월.xlsx', sheet_name=None)
        
        # 모든 시트 정보 출력
        print(f"=== 78월.xlsx 파일 분석 ===\n")
        print(f"시트 개수: {len(df)}")
        
        all_leave_data = []
        
        for sheet_name, sheet_df in df.items():
            print(f"\n시트: {sheet_name}")
            print(f"행 수: {len(sheet_df)}")
            print(f"열: {list(sheet_df.columns)}")
            
            # 데이터 샘플 출력
            if len(sheet_df) > 0:
                print("\n샘플 데이터 (처음 5행):")
                print(sheet_df.head())
                
                # 연차 관련 데이터 추출
                for index, row in sheet_df.iterrows():
                    row_dict = row.to_dict()
                    # JSON으로 저장
                    all_leave_data.append({
                        'sheet': sheet_name,
                        'row': index,
                        'data': {k: str(v) if pd.notna(v) else None for k, v in row_dict.items()}
                    })
        
        # JSON 파일로 저장
        with open('excel_data.json', 'w', encoding='utf-8') as f:
            json.dump(all_leave_data, f, ensure_ascii=False, indent=2)
        
        print(f"\n총 {len(all_leave_data)}개 행의 데이터를 excel_data.json 파일로 저장했습니다.")
        
    except Exception as e:
        print(f"에러 발생: {e}")
        print("\n대체 방법: Numbers 앱으로 열어서 CSV로 내보내기")
        print("open -a Numbers 78월.xlsx")

if __name__ == "__main__":
    parse_excel()