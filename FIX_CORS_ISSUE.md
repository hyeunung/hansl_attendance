# CORS 및 Supabase 접속 문제 해결 가이드

## 문제 상황
- `https://hansl-workspace.com`에서 Supabase API로 요청 시 CORS 에러 발생
- Supabase API가 HTTP 500 에러 반환

## 해결 방법

### 1. Supabase Dashboard 접속
다음 URL로 접속하여 프로젝트 상태 확인:
```
https://supabase.com/dashboard/project/qvhbigvdfyvhoegkhvef
```

### 2. CORS 설정 확인 및 수정

#### 방법 1: Supabase Dashboard에서 설정
1. **Settings** → **API** 메뉴로 이동
2. **CORS** 섹션에서 다음 도메인 추가:
   - `https://hansl-workspace.com`
   - `https://www.hansl-workspace.com` (필요시)

#### 방법 2: SQL로 직접 설정 (고급)
Supabase SQL Editor에서 다음 쿼리 실행:
```sql
-- CORS 설정 확인 (현재 설정 확인)
SELECT * FROM pg_settings WHERE name LIKE '%cors%';

-- 참고: Supabase는 대시보드에서 CORS를 관리합니다.
-- 직접 SQL로는 설정할 수 없으므로 Dashboard를 사용하세요.
```

### 3. 프로젝트 상태 확인
1. **Settings** → **General**에서 프로젝트 상태 확인
2. 프로젝트가 **Paused** 상태인지 확인
3. 프로젝트가 일시정지되어 있다면 **Resume** 클릭

### 4. API 키 확인
1. **Settings** → **API**에서 다음 정보 확인:
   - Project URL: `https://qvhbigvdfyvhoegkhvef.supabase.co`
   - anon/public key: 정상적으로 표시되는지 확인
   - service_role key: 서버 사이드에서만 사용

### 5. 추가 확인 사항

#### 프로젝트 일시정지 여부 확인
Supabase 무료 플랜의 경우 일정 기간 비활성 시 프로젝트가 일시정지될 수 있습니다.

#### 네트워크 연결 확인
터미널에서 다음 명령어로 API 응답 확인:
```bash
curl -I https://qvhbigvdfyvhoegkhvef.supabase.co/rest/v1/
```

정상 응답: `200 OK`
현재 응답: `500 Internal Server Error` (문제 있음)

### 6. 임시 해결 방법 (개발 환경)

로컬 개발 환경에서 테스트할 경우:
1. 로컬 Supabase 실행:
   ```bash
   cd /Users/scott/workspace/hansl
   supabase start
   ```
2. 로컬 Supabase Studio 접속:
   ```
   http://localhost:54323
   ```

### 7. 프로덕션 환경 해결

프로덕션 환경(`hansl-workspace.com`)에서 사용하려면:
1. Supabase Dashboard에서 CORS 설정에 도메인 추가
2. 프로젝트가 활성 상태인지 확인
3. API 키가 유효한지 확인

## 참고 사항

- CORS 설정은 Supabase Dashboard에서만 변경 가능합니다
- 프로젝트가 일시정지되어 있다면 Resume 후 몇 분 기다려야 합니다
- 무료 플랜의 경우 일정 기간 비활성 시 자동 일시정지됩니다

## 문의
문제가 지속되면 Supabase 지원팀에 문의하세요:
- Support: https://supabase.com/support
- Discord: https://discord.supabase.com












