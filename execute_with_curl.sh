#\!/bin/bash

# Supabase REST API를 통해 데이터 삽입
SUPABASE_URL="https://qvhbigvdfyvhoegkhvef.supabase.co"
SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo"

echo "김경태님 공가 처리 중..."

# 1/31 공가 등록
curl -X POST "${SUPABASE_URL}/rest/v1/leave_requests" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
  -d '{
    "user_email": "kkt@hansl.com",
    "type": "official",
    "start_date": "2025-01-31",
    "end_date": "2025-01-31",
    "days": 1,
    "reason": "장인어른 상",
    "status": "approved"
  }'

echo ""
echo "1/31 공가 등록 완료"

# 2/11~2/13 공가 등록
curl -X POST "${SUPABASE_URL}/rest/v1/leave_requests" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
  -d '{
    "user_email": "kkt@hansl.com",
    "type": "official",
    "start_date": "2025-02-11",
    "end_date": "2025-02-13",
    "days": 3,
    "reason": "할머니 상",
    "status": "approved"
  }'

echo ""
echo "2/11~2/13 공가 등록 완료"

# 결과 확인
echo ""
echo "등록된 공가 확인:"
curl -X GET "${SUPABASE_URL}/rest/v1/leave_requests?user_email=eq.kkt@hansl.com&type=eq.official&select=start_date,end_date,reason,days" \
  -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}"

echo ""
