# Supabase 새로운 API 키 시스템 안내

## 🔄 변경 사항

Supabase가 새로운 API 키 시스템을 도입했습니다:

### 기존 시스템 (Legacy)
- **Anon Key**: JWT 형식 (`eyJhbGci...`)
- **Service Role Key**: JWT 형식 (`eyJhbGci...`)
- 위치: **"Legacy anon, service_role API keys"** 탭

### 새로운 시스템
- **Publishable Key**: `sb_publishable_...` 형식
- **Secret Key**: `sb_secret_...` 형식
- 위치: **"Publishable and secret API keys"** 탭 (기본 탭)

## ✅ 좋은 소식

### 1. 기존 코드는 계속 작동합니다!
- Legacy 키들은 **여전히 유효**합니다
- 기존 코드를 수정할 필요가 **없습니다**
- Legacy 탭에서 키를 확인하고 사용할 수 있습니다

### 2. 마이그레이션은 선택사항입니다
- Supabase는 새 키 시스템 사용을 권장하지만 **강제하지 않습니다**
- 기존 Legacy 키로 계속 사용 가능합니다
- 필요할 때 마이그레이션하면 됩니다

## 📋 현재 상황

### 코드베이스 상태
- 모든 코드가 **Legacy 키 (JWT 형식)** 사용 중
- `lib/main.dart`, JavaScript 파일들 모두 Legacy 키 사용
- **수정 불필요** - 그대로 사용 가능

### Dashboard 상태
- **Legacy 탭**: 기존 anon key, service_role key 존재 ✅
- **새 탭**: Publishable key, Secret key 생성됨 (사용 안 함)

## 🎯 권장 사항

### 지금 당장 할 것
1. **아무것도 하지 않아도 됩니다!**
   - 기존 코드 그대로 사용
   - Legacy 키 계속 사용 가능

2. **Service Role Key 확인**
   - Legacy 탭에서 "Reveal" 버튼으로 전체 키 확인
   - 코드베이스의 키와 일치하는지 확인

### 나중에 할 것 (선택사항)
1. **새 키 시스템으로 마이그레이션**
   - 새 Publishable/Secret 키 사용
   - 모든 코드 업데이트 필요
   - 지금은 필요 없음

2. **Legacy 키 비활성화**
   - 새 키로 완전히 마이그레이션한 후에만
   - "Disable legacy API keys" 버튼 사용

## ⚠️ 주의사항

1. **"Disable legacy API keys" 버튼 주의**
   - 이 버튼을 누르면 Legacy 키가 비활성화됩니다
   - 새 키로 마이그레이션하기 전까지 **절대 누르지 마세요**

2. **키 백업**
   - Service Role Key를 Reveal하여 확인
   - 안전한 곳에 백업 (1Password, Bitwarden 등)

3. **코드 업데이트 불필요**
   - 지금은 기존 코드 그대로 사용하세요
   - 마이그레이션은 나중에 계획적으로 진행

## 🔍 확인 사항

### Legacy 키가 정상 작동하는지 테스트
```bash
# Anon Key 테스트
curl -H "apikey: [Legacy Anon Key]" \
     -H "Authorization: Bearer [Legacy Anon Key]" \
     "https://qvhbigvdfyvhoegkhvef.supabase.co/rest/v1/"
```

정상 응답이면 Legacy 키가 정상 작동하는 것입니다!

## 📝 요약

- ✅ Supabase가 새 키 시스템 도입
- ✅ 기존 Legacy 키는 계속 작동
- ✅ 코드 수정 불필요
- ✅ 마이그레이션은 선택사항
- ⚠️ "Disable legacy API keys" 버튼 주의

**결론**: 지금은 아무것도 할 필요 없습니다! 기존 코드 그대로 사용하세요.










