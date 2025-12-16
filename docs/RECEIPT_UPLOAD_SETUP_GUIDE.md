# 📸 영수증 업로드 시스템 설정 가이드

## 🎯 개요

모바일 앱에서 구매 영수증을 촬영하여 업로드하고, PC 웹에서 다운로드할 수 있는 시스템입니다.

---

## 📋 1. Supabase Storage 버킷 생성

### Supabase Dashboard에서 수동 설정:

1. **Supabase Dashboard** 접속
2. **Storage** → **Create a new bucket**
3. 설정:
   ```
   Name: receipt-images
   Public: false (비공개)
   File size limit: 10 MB
   Allowed MIME types: image/jpeg, image/jpg, image/png, image/heic, image/webp
   ```

---

## 🔐 2. Storage RLS 정책 설정

Supabase Dashboard → **Storage** → **receipt-images** → **Policies**에서 다음 정책들을 추가:

### 정책 1: 업로드 (INSERT)
```sql
Policy name: Authenticated users can upload receipts
Policy definition: FOR INSERT
Target roles: authenticated

USING expression:
bucket_id = 'receipt-images' AND auth.uid() IS NOT NULL

WITH CHECK expression:
bucket_id = 'receipt-images' AND auth.uid() IS NOT NULL
```

### 정책 2: 조회 (SELECT)
```sql
Policy name: Authenticated users can view receipts
Policy definition: FOR SELECT
Target roles: authenticated

USING expression:
bucket_id = 'receipt-images'
```

### 정책 3: 삭제 (DELETE)
```sql
Policy name: Owner or lead_buyer can delete receipts
Policy definition: FOR DELETE
Target roles: authenticated

USING expression:
bucket_id = 'receipt-images' 
AND (
  auth.uid() = owner 
  OR EXISTS (
    SELECT 1 FROM employees 
    WHERE email = auth.email()
    AND 'lead_buyer' = ANY(purchase_role)
  )
)
```

### 정책 4: 수정 (UPDATE)
```sql
Policy name: Owner can update receipts
Policy definition: FOR UPDATE
Target roles: authenticated

USING expression:
bucket_id = 'receipt-images' AND auth.uid() = owner

WITH CHECK expression:
bucket_id = 'receipt-images' AND auth.uid() = owner
```

---

## 📱 3. 모바일 앱 사용법

### Flutter 앱에서 영수증 업로드:

```dart
import 'package:hansl/widgets/purchase/receipt_upload_button.dart';

// 구매대기 또는 입고대기 화면의 품목 카드에 추가
ReceiptUploadButton(
  purchaseRequestId: item.purchaseRequestId,
  itemId: item.id,
  currentReceiptUrl: item.receiptImageUrl,
  onUploadComplete: () {
    // 업로드 완료 후 화면 새로고침
    setState(() {});
  },
)
```

### 사용자 플로우:
1. **구매대기/입고대기 화면**에서 품목 선택
2. **📷 카메라 아이콘** 클릭
3. **카메라 촬영** 또는 **갤러리 선택**
4. 자동으로 Supabase Storage에 업로드
5. DB(`purchase_request_items`)에 URL 저장

---

## 💻 4. 웹앱 사용법

### React 웹앱에서 영수증 다운로드:

```tsx
import { ReceiptDownloadButton } from '@/components/purchase/ReceiptDownloadButton';

// 발주 목록 테이블에 컬럼 추가
{
  header: '영수증',
  cell: (item) => (
    <ReceiptDownloadButton
      itemId={item.id}
      receiptUrl={item.receipt_image_url}
      itemName={item.item_name}
      onUpdate={() => refetch()}
    />
  ),
}
```

### 구매 담당자 플로우:
1. **웹앱 발주 목록**에서 영수증 확인
2. **보기** 버튼: 미리보기 모달 또는 새 탭
3. **다운로드** 버튼: PC에 저장

---

## 🗄️ 5. DB 구조

### `purchase_request_items` 테이블 추가 컬럼:

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| `receipt_image_url` | TEXT | 영수증 이미지 URL |
| `receipt_uploaded_at` | TIMESTAMPTZ | 업로드 시각 |
| `receipt_uploaded_by` | TEXT | 업로드한 직원 이메일 |

### Storage 파일 경로:
```
receipts/{purchase_request_id}/{item_id}_{timestamp}.jpg
```

예시:
```
receipts/1234/5678_1730000000000.jpg
```

---

## 🔧 6. 패키지 설치

### Flutter 앱:
```bash
cd /Users/scott/workspace/hansl
flutter pub get
```

필요 패키지 (이미 `pubspec.yaml`에 추가됨):
- `image_picker: ^1.1.2`
- `path: ^1.9.0`

### 웹앱:
```bash
cd /Users/scott/workspace/hanslworkspace
npm install
```

필요 패키지:
- `@supabase/supabase-js` (이미 설치됨)
- `lucide-react` (아이콘, 이미 설치됨)

---

## ✅ 7. 테스트 체크리스트

### 모바일 앱:
- [ ] 카메라 촬영 → 업로드 성공
- [ ] 갤러리 선택 → 업로드 성공
- [ ] 영수증 보기 → 이미지 표시
- [ ] 영수증 삭제 → Storage + DB 삭제

### 웹앱:
- [ ] 영수증 보기 → 미리보기 모달
- [ ] 영수증 다운로드 → PC 저장
- [ ] 영수증 없는 품목 → "영수증 없음" 표시

---

## 🚨 주의사항

1. **Storage 버킷 수동 생성 필수**
   - Migration으로 자동 생성 불가
   - Supabase Dashboard에서 수동으로 `receipt-images` 버킷 생성 필요

2. **RLS 정책 수동 설정 필수**
   - Storage RLS는 SQL Migration 적용 안됨
   - Supabase Dashboard → Storage → Policies에서 수동 설정

3. **iOS 권한 설정**
   - `ios/Runner/Info.plist`에 카메라/사진 권한 추가 필요:
     ```xml
     <key>NSCameraUsageDescription</key>
     <string>영수증 촬영을 위해 카메라 접근이 필요합니다.</string>
     <key>NSPhotoLibraryUsageDescription</key>
     <string>영수증 선택을 위해 사진 라이브러리 접근이 필요합니다.</string>
     ```

4. **Android 권한 설정**
   - `android/app/src/main/AndroidManifest.xml`에 카메라 권한 추가:
     ```xml
     <uses-permission android:name="android.permission.CAMERA"/>
     <uses-feature android:name="android.hardware.camera" android:required="false"/>
     ```

---

## 📊 데이터 플로우

```
┌─────────────┐      ┌──────────────────┐      ┌──────────────┐
│ 모바일 앱   │──1──>│ Supabase Storage │<──2──│  PC 웹앱     │
│ (직원 촬영) │      │ (receipt-images) │      │ (담당자 확인)│
└─────────────┘      └──────────────────┘      └──────────────┘
       │                       │                        │
       │                       │                        │
       └───────────3───────────┴────────────4───────────┘
                              │
                    ┌─────────▼──────────┐
                    │ purchase_request_  │
                    │      items         │
                    │ (receipt_image_url)│
                    └────────────────────┘
```

1. 직원이 앱에서 영수증 촬영 → Storage 업로드
2. Storage URL을 DB에 저장
3. 웹앱에서 DB 조회
4. 웹앱에서 Storage에서 다운로드

---

## 🔄 업데이트 히스토리

- **2025-10-27**: 초기 시스템 구현
  - DB 마이그레이션 완료
  - Flutter 앱 업로드 서비스 구현
  - 웹앱 다운로드 컴포넌트 구현



