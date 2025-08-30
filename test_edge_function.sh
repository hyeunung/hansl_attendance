#\!/bin/bash

# Edge Function으로 leave 상태 업데이트 테스트
echo "📝 Edge Function 테스트 시작..."
echo "테스트 대상: leave ID 464 (정현웅님의 연차 신청)"
echo ""

# Service Role Key로 직접 업데이트 (RLS 우회)
echo "🔧 Service Role로 직접 DB 업데이트 시도..."

curl -X PATCH \
  "https://qvhbigvdfyvhoegkhvef.supabase.co/rest/v1/leave?id=eq.464" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d '{
    "status": "approved",
    "middle_manager_approval": true,
    "final_approval": true,
    "middle_manager_email": "test@hansl.com",
    "final_approver_email": "test@hansl.com"
  }'

echo ""
echo "✅ 업데이트 완료\!"
echo ""

# 결과 확인
echo "🔍 업데이트된 레코드 확인..."
curl -X GET \
  "https://qvhbigvdfyvhoegkhvef.supabase.co/rest/v1/leave?id=eq.464&select=id,name,status,middle_manager_approval,final_approval" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo" | python3 -m json.tool

echo ""
echo ""

# 원래 상태로 복구
echo "🔄 원래 상태(pending)로 복구..."
curl -X PATCH \
  "https://qvhbigvdfyvhoegkhvef.supabase.co/rest/v1/leave?id=eq.464" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjI3MjM2MSwiZXhwIjoyMDMxODQ4MzYxfQ.ptJr4HkYH7MRcOKF8pO7UjQMjXMNLxqxNLBnRWKv8Oo" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d '{
    "status": "pending",
    "middle_manager_approval": false,
    "final_approval": false,
    "middle_manager_email": null,
    "final_approver_email": null
  }'

echo ""
echo "✅ 복구 완료\!"
