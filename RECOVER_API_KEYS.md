# Supabase API 키 복구 가이드

## 🚨 현재 상황
Supabase Dashboard에서 기존 API 키(anon key, service_role key)가 보이지 않습니다.
이는 Supabase가 새로운 API 키 시스템을 도입했기 때문일 수 있습니다.

## ✅ 좋은 소식
코드베이스에 기존 API 키들이 하드코딩되어 있어 복구 가능합니다!

## 📋 복구할 키 정보

### 1. Anon Key (Publishable Key)
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg
```

### 2. Service Role Key (Secret Key)
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgxNDM2MCwiZXhwIjoyMDYzMzkwMzYwfQ.CTunNqWEcvsAo42kcKVSpSkHK66M1OIjlhdvIoCxn78
```

## 🔍 Dashboard에서 기존 키 찾는 방법

### 방법 1: Settings → API → Project API keys
1. Supabase Dashboard 접속
2. **Settings** → **API** 메뉴로 이동
3. **Project API keys** 섹션 확인
   - 여기에 기존 JWT 형식의 키들이 있을 수 있습니다
   - "anon" key와 "service_role" key를 찾아보세요

### 방법 2: Settings → General
1. **Settings** → **General** 메뉴로 이동
2. **Reference ID** 섹션 확인
3. API URL과 함께 키 정보가 표시될 수 있습니다

### 방법 3: JWT Keys 섹션
1. **Settings** → **JWT Keys** 메뉴로 이동
2. 여기서 JWT 시크릿을 확인할 수 있습니다

## 🔧 키가 정말 사라졌다면

### 옵션 1: Supabase 지원팀에 문의
- Supabase는 키를 자동으로 삭제하지 않습니다
- 프로젝트가 일시정지되었거나 다른 문제일 수 있습니다
- 지원팀에 문의: https://supabase.com/support

### 옵션 2: 새 키 생성 (최후의 수단)
⚠️ **주의**: 새 키를 생성하면 기존 키는 무효화됩니다!

1. Dashboard → **Settings** → **API**
2. **Create new API keys** 클릭
3. 새 키 생성 후 모든 코드와 환경변수 업데이트 필요

## 📝 코드베이스에서 키 위치

### 하드코딩된 키 위치:
1. `lib/main.dart` (line 78) - Anon Key
2. `test_all_push_notifications_with_db.sh` (line 11-12) - Anon Key & Service Key
3. 여러 JavaScript 파일들:
   - `check_jhw_leave.js`
   - `add_jhw_attendance_1201.js`
   - `check_jhw_leave_history.js`
   - `fix_jhw_leave.js`
   - `check_specific_employees.js`
   - `fix_inconsistent_data.js`
   - `investigate_inconsistent_employees.js`
   - `check_all_employees.js`
   - `debug_annual_leave.js`

## ✅ 즉시 확인 방법

터미널에서 다음 명령어로 키가 작동하는지 확인:

```bash
# Anon Key 테스트
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg" \
     -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2aGJpZ3ZkZnl2aG9lZ2todmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MTQzNjAsImV4cCI6MjA2MzM5MDM2MH0.7VZlSwnNuE0MaQpDjuzeZFgjJrDBQOWA_COyqaM8Rbg" \
     "https://qvhbigvdfyvhoegkhvef.supabase.co/rest/v1/"

# 정상 응답이면 키가 작동하는 것입니다!
```

## 🎯 권장 조치

1. **즉시**: 위의 curl 명령어로 키 작동 여부 확인
2. **Dashboard 확인**: Settings → API → Project API keys 섹션 확인
3. **지원팀 문의**: 키가 정말 사라졌다면 Supabase 지원팀에 문의
4. **백업**: 키를 안전한 곳에 백업 (1Password, Bitwarden 등)

## ⚠️ 중요 사항

- **절대 새 키를 생성하지 마세요** (기존 키가 무효화됨)
- 키가 작동한다면 Dashboard UI 문제일 수 있습니다
- 코드베이스에 키가 있으므로 앱은 계속 작동할 것입니다



















