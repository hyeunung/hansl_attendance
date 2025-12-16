# 📸 영수증 시스템 통합 가이드

## ⚠️ **중요: 현장결제 항목만 해당**

영수증 업로드/다운로드 기능은 **현장결제(`payment_category = '현장 결제'`)** 항목에만 표시됩니다.

---

## 🎯 **추천 배치 위치**

### Flutter 앱:
- **입고대기 탭** - 현장결제 품목 입고 시 영수증 등록
- **구매대기 탭** - 현장결제 구매 후 영수증 등록

### 웹앱:
- **발주 상세 모달** - 현장결제 품목의 영수증 확인/다운로드

---

## 📱 **Flutter 통합 예시**

### 구매대기 탭에 추가:

```dart
// lib/widgets/purchase/purchase_waiting_widget.dart

// 1. Import 추가
import 'receipt_upload_button.dart';

// 2. 품목 카드 내부에 추가 (금액 표시 아래)
Text('금액: ${numberFormat.format(item['amount_value'])}원', ...),
SizedBox(height: 8),

// 영수증 버튼 (현장결제만 표시)
ReceiptUploadButton(
  purchaseRequestId: item['purchase_request_id'],
  itemId: item['id'],
  currentReceiptUrl: item['receipt_image_url'],
  paymentCategory: firstItem['payment_category'], // 발주 단위로 현장결제 구분
  onUploadComplete: () => _loadPurchaseItems(),
),
```

### 입고대기 탭에 추가:

```dart
// lib/widgets/purchase/receiving_waiting_widget.dart

// 1. Import 추가
import 'receipt_upload_button.dart';

// 2. 품목 카드 내부에 추가
Text('금액: ${numberFormat.format(item['amount_value'])}원', ...),
SizedBox(height: 8),

// 영수증 버튼 (현장결제만 표시)
ReceiptUploadButton(
  purchaseRequestId: item['purchase_request_id'],
  itemId: item['id'],
  currentReceiptUrl: item['receipt_image_url'],
  paymentCategory: firstItem['payment_category'],
  onUploadComplete: () => _loadReceivingItems(),
),
```

---

## 💻 **웹앱 통합 예시**

### 발주 상세 모달 (PurchaseItemsModal.tsx):

```tsx
// 1. Import 추가
import { ReceiptDownloadButton } from './ReceiptDownloadButton';

// 2. 테이블 헤더에 "영수증" 컬럼 추가 (현장결제만)
{purchase.payment_category === '현장 결제' && <TableHead>영수증</TableHead>}

// 3. 테이블 바디에 버튼 추가
{purchase.payment_category === '현장 결제' && (
  <TableCell>
    <ReceiptDownloadButton
      itemId={Number(item.id)}
      receiptUrl={item.receipt_image_url}
      itemName={item.item_name}
      paymentCategory={purchase.payment_category}
      onUpdate={onUpdate}
    />
  </TableCell>
)}
```

---

## 🔍 **현장결제 확인 방법**

### DB에서 현장결제 건수 확인:
```sql
SELECT 
  COUNT(*) as 현장결제_건수,
  COUNT(DISTINCT purchase_request_id) as 현장결제_발주_건수
FROM purchase_request_items pri
JOIN purchase_requests pr ON pri.purchase_request_id = pr.id
WHERE pr.payment_category IN ('현장 결제', '현장결제');
```

---

## 🎨 **UI 동작**

### 현장결제 항목:
```
┌────────────────────────┐
│ 품목: 부품 A           │
│ 금액: 50,000원         │
│                        │
│ [📷 영수증 촬영]       │  ← 표시됨
└────────────────────────┘
```

### 일반 구매 항목:
```
┌────────────────────────┐
│ 품목: 부품 B           │
│ 금액: 1,000,000원      │
│                        │
│ (영수증 버튼 없음)     │  ← 표시 안됨
└────────────────────────┘
```

---

## ✅ **이제 정확합니다!**

- ✅ 현장결제 항목 → 영수증 버튼 **표시**
- ❌ 일반 구매/발주 → 영수증 버튼 **숨김**

**어디에 배치할지만 결정하시면 됩니다!**


