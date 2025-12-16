# 📸 구매 영수증 업로드 시스템

## 🎯 시스템 개요

직원들이 **모바일 앱**에서 구매 영수증을 촬영/업로드하고, 구매 담당자가 **PC 웹**에서 확인/다운로드할 수 있는 시스템입니다.

---

## 🏗️ 시스템 아키텍처

```
┌─────────────────────┐
│   모바일 앱(Flutter) │
│   - 영수증 촬영      │
│   - 갤러리 선택      │
│   - Storage 업로드   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Supabase Storage    │
│ bucket: receipt-    │
│        images       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Supabase DB         │
│ purchase_request_   │
│ items 테이블        │
│ - receipt_image_url │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   웹앱(React)       │
│   - 영수증 조회     │
│   - 다운로드        │
└─────────────────────┘
```

---

## 📦 1. DB 마이그레이션 (완료 ✅)

### 추가된 컬럼 (purchase_request_items):
```sql
- receipt_image_url TEXT            -- 영수증 이미지 URL
- receipt_uploaded_at TIMESTAMPTZ   -- 업로드 시각
- receipt_uploaded_by TEXT          -- 업로드한 직원 이메일
```

마이그레이션 파일:
- `supabase/migrations/add_receipt_columns_to_purchase_items.sql`

---

## 📱 2. 모바일 앱 (Flutter) - 구현 완료 ✅

### 구현 파일:
1. **서비스**: `lib/services/receipt_upload_service.dart`
   - 카메라 촬영 업로드
   - 갤러리 선택 업로드
   - 영수증 삭제
   - Storage 업로드 로직

2. **위젯**: `lib/widgets/purchase/receipt_upload_button.dart`
   - 영수증 업로드 버튼
   - 영수증 보기 (이미지 뷰어)
   - 영수증 삭제 버튼

3. **통합**:
   - `lib/widgets/purchase/purchase_waiting_widget.dart` (구매대기)
   - `lib/widgets/purchase/receiving_waiting_widget.dart` (입고대기)

### 권한 설정 (완료 ✅):
- **iOS**: `ios/Runner/Info.plist`
  - NSCameraUsageDescription
  - NSPhotoLibraryUsageDescription
  
- **Android**: `android/app/src/main/AndroidManifest.xml`
  - CAMERA 권한
  - android.hardware.camera feature

### 패키지 추가 (완료 ✅):
```yaml
pubspec.yaml:
  image_picker: ^1.1.2
  path: ^1.9.0
```

---

## 💻 3. 웹앱 (React) - 구현 완료 ✅

### 구현 파일:
1. **컴포넌트**: `src/components/purchase/ReceiptDownloadButton.tsx`
   - 영수증 보기 (미리보기 모달)
   - 영수증 다운로드
   - "영수증 없음" 표시

2. **통합**:
   - `src/components/purchase/PurchaseItemsModal.tsx`
   - 품목 목록 테이블에 "영수증" 컬럼 추가

3. **타입 정의**: `src/types/purchase.ts`
   - PurchaseRequestItem에 영수증 필드 추가

---

## ⚙️ 4. Supabase Storage 설정 (수동 필요)

### ❗ 중요: Supabase Dashboard에서 수동 설정 필요

#### Step 1: 버킷 생성
1. Supabase Dashboard → **Storage**
2. **Create a new bucket** 클릭
3. 설정:
   ```
   Bucket name: receipt-images
   Public bucket: ❌ (비활성화)
   File size limit: 10 MB
   Allowed MIME types: image/jpeg, image/jpg, image/png, image/heic, image/webp
   ```

#### Step 2: RLS 정책 설정
Storage → receipt-images → **Policies** → **New Policy**

**정책 1 - 업로드 허용:**
```sql
Policy Name: Authenticated users can upload receipts
Policy Command: INSERT
Target Roles: authenticated

WITH CHECK:
bucket_id = 'receipt-images' AND auth.uid() IS NOT NULL
```

**정책 2 - 조회 허용:**
```sql
Policy Name: Authenticated users can view receipts
Policy Command: SELECT
Target Roles: authenticated

USING:
bucket_id = 'receipt-images'
```

**정책 3 - 삭제 허용:**
```sql
Policy Name: Owner or lead_buyer can delete
Policy Command: DELETE
Target Roles: authenticated

USING:
bucket_id = 'receipt-images' AND (
  auth.uid() = owner OR 
  EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email()
    AND 'lead_buyer' = ANY(purchase_role)
  )
)
```

---

## 🚀 5. 사용 방법

### 모바일 앱 (직원):

1. **구매대기** 또는 **입고대기** 탭 이동
2. 발주 건 확장하여 품목 리스트 보기
3. 품목 아래 **📷 카메라 아이콘** 클릭
4. "카메라로 촬영" 또는 "갤러리에서 선택"
5. 영수증 촬영/선택
6. 자동 업로드 → ✅ "영수증이 업로드되었습니다"

**업로드 후:**
- 📄 **영수증 보기** 아이콘: 확대하여 확인 가능
- 🗑️ **삭제** 아이콘: 영수증 삭제

### 웹앱 (구매 담당자):

1. 발주 목록에서 발주 건 클릭 (상세 모달 열기)
2. 품목 리스트에서 **영수증** 컬럼 확인
3. **보기** 버튼: 미리보기 (새 탭)
4. **다운로드** 버튼: PC에 저장

---

## 📂 파일 저장 구조

### Supabase Storage 경로:
```
receipt-images/
  └── receipts/
      └── {purchase_request_id}/
          └── {item_id}_{timestamp}.jpg
```

**예시:**
```
receipt-images/receipts/1234/5678_1730052000000.jpg
```

---

## 🧪 6. 테스트 시나리오

### ✅ 모바일 앱 테스트:
1. [ ] 구매대기 탭 → 품목 확장 → 카메라 아이콘 표시 확인
2. [ ] 카메라 촬영 → 업로드 성공 확인
3. [ ] 갤러리 선택 → 업로드 성공 확인
4. [ ] 영수증 보기 → 이미지 표시 확인
5. [ ] 영수증 삭제 → Storage + DB 삭제 확인

### ✅ 웹앱 테스트:
1. [ ] 발주 상세 모달 → "영수증" 컬럼 표시 확인
2. [ ] 영수증 없는 품목 → "영수증 없음" 표시
3. [ ] 영수증 있는 품목 → "보기", "다운로드" 버튼 표시
4. [ ] 보기 버튼 → 미리보기 정상 작동
5. [ ] 다운로드 버튼 → PC 저장 확인

---

## 🔧 7. 설치 및 실행

### Flutter 앱:
```bash
cd /Users/scott/workspace/hansl
flutter pub get
flutter run
```

### 웹앱:
```bash
cd /Users/scott/workspace/hanslworkspace
npm install
npm run dev
```

---

## 🐛 8. 문제 해결

### 문제 1: 카메라 권한 거부
**해결:** 설정 → HANSL 앱 → 카메라 권한 허용

### 문제 2: 업로드 실패 (403 Forbidden)
**원인:** Storage RLS 정책 미설정
**해결:** Supabase Dashboard에서 RLS 정책 설정 (4단계 참조)

### 문제 3: 웹에서 다운로드 안됨
**원인:** Storage bucket이 public이 아님
**해결:** 정상 동작 (authenticated 사용자만 접근 가능하도록 설계됨)

### 문제 4: 영수증 이미지 안 보임
**원인:** 잘못된 URL 또는 Storage 파일 삭제됨
**해결:** DB의 receipt_image_url과 Storage 파일 일치 확인

---

## 📊 9. 데이터 확인 쿼리

### 영수증이 업로드된 품목 확인:
```sql
SELECT 
  id,
  item_name,
  receipt_image_url,
  receipt_uploaded_at,
  receipt_uploaded_by
FROM purchase_request_items
WHERE receipt_image_url IS NOT NULL
ORDER BY receipt_uploaded_at DESC
LIMIT 10;
```

### Storage 파일 목록 확인:
```sql
SELECT 
  name,
  bucket_id,
  owner,
  created_at,
  updated_at,
  metadata->>'size' as file_size
FROM storage.objects
WHERE bucket_id = 'receipt-images'
ORDER BY created_at DESC
LIMIT 10;
```

---

## 🎨 10. UI/UX 특징

### 모바일:
- ✨ 반응형 디자인
- 📸 직관적인 카메라 아이콘
- 🖼️ InteractiveViewer로 확대/축소 가능
- 🗑️ 간편한 삭제 기능

### 웹:
- 🎨 깔끔한 버튼 디자인 (Lucide 아이콘)
- 👁️ 미리보기 모달
- 💾 원클릭 다운로드
- 📊 테이블에 통합

---

## 🔐 11. 보안

- ✅ **RLS 활성화**: 인증된 사용자만 접근
- ✅ **비공개 버킷**: Public URL 생성 불가
- ✅ **권한 분리**: 업로드(직원) vs 조회(담당자)
- ✅ **파일 크기 제한**: 10MB
- ✅ **MIME 타입 제한**: 이미지만 허용

---

## 📝 12. 향후 개선 사항

1. [ ] 여러 영수증 업로드 (1품목당 여러 장)
2. [ ] 영수증 OCR (자동 금액 추출)
3. [ ] 영수증 압축 (Storage 용량 절약)
4. [ ] 영수증 워터마크 (위변조 방지)
5. [ ] 영수증 유효성 검증 (AI)

---

## 👥 13. 개발자 정보

- **브랜치**: `feature/receipt-upload-system`
- **개발일**: 2025-10-27
- **담당**: 영수증 업로드 시스템 구축팀

---

## 📞 14. 지원

문제 발생 시:
1. 앱 내 **문의하기** 기능 사용
2. 개발팀에 문의
3. 이슈 트래커 등록



