# 🔐 보안 설정 가이드

## 환경 변수 설정

### 1. .env 파일 생성
```bash
# .env.example을 복사하여 .env 파일 생성
cp .env.example .env
```

### 2. Supabase 설정 추가
`.env` 파일을 편집하여 실제 값 입력:
```env
# Supabase 프로젝트 URL (Supabase Dashboard에서 확인)
SUPABASE_URL=https://qvhbigvdfyvhoegkhvef.supabase.co

# Supabase Anon Key (공개 키 - 클라이언트에서 사용 가능)
SUPABASE_ANON_KEY=your_actual_anon_key_here

# Supabase Service Role Key (비밀 키 - 서버에서만 사용!)
# ⚠️ 절대 클라이언트 코드에 포함하지 마세요!
SUPABASE_SERVICE_KEY=your_actual_service_key_here
```

### 3. 중요 보안 규칙

#### ✅ 해야 할 것
- `.env` 파일은 **절대** Git에 커밋하지 마세요
- `.gitignore`에 `.env`가 포함되어 있는지 확인
- 프로덕션 환경에서는 환경 변수를 안전하게 관리
- Service Role Key는 서버 사이드에서만 사용

#### ❌ 하지 말아야 할 것
- 소스 코드에 API 키 하드코딩
- `.env` 파일을 공유 저장소에 업로드
- Service Role Key를 클라이언트 코드에 포함
- 공개 저장소에 실제 키 값 노출

## 보안 체크리스트

- [ ] `.env` 파일이 `.gitignore`에 포함되어 있는가?
- [ ] 소스 코드에 하드코딩된 키가 없는가?
- [ ] Service Role Key가 클라이언트 코드에 없는가?
- [ ] 환경 변수가 올바르게 로드되는가?

## 환경별 설정

### 개발 환경
- `.env` 파일 사용 가능 (로컬 개발용)

### 프로덕션 환경
- 환경 변수를 플랫폼에서 직접 설정
- CI/CD 파이프라인에서 안전하게 관리
- Secret Manager 사용 권장

## 문제 해결

### 환경 변수가 로드되지 않을 때
1. `.env` 파일이 프로젝트 루트에 있는지 확인
2. 파일 권한 확인 (읽기 가능한지)
3. 앱을 완전히 재시작 (`flutter clean && flutter run`)

### 보안 감사
정기적으로 다음 명령으로 하드코딩된 키 확인:
```bash
# Supabase 키 검색
grep -r "eyJhbGciOiJ" lib/
grep -r "qvhbigvdfyvhoegkhvef" lib/
```

## 긴급 상황 대응

만약 키가 노출되었다면:
1. **즉시** Supabase Dashboard에서 키 재생성
2. 모든 환경의 `.env` 파일 업데이트
3. 배포된 앱 업데이트
4. 로그 확인 및 비정상 활동 모니터링