import React from 'react';
import { createClient } from '@supabase/supabase-js';

interface ReceiptDownloadButtonProps {
  itemId: number;
  receiptUrl?: string | null;
  itemName: string;
}

/**
 * 웹앱용 영수증 다운로드 버튼
 * 구매 담당자가 영수증을 다운로드할 수 있습니다
 */
export const ReceiptDownloadButton: React.FC<ReceiptDownloadButtonProps> = ({
  itemId,
  receiptUrl,
  itemName,
}) => {
  const [isLoading, setIsLoading] = React.useState(false);

  // Supabase 클라이언트 초기화
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  /**
   * 영수증 다운로드 핸들러
   */
  const handleDownload = async () => {
    if (!receiptUrl) return;

    setIsLoading(true);

    try {
      // URL에서 파일 경로 추출
      const url = new URL(receiptUrl);
      const pathSegments = url.pathname.split('/');
      const bucketIndex = pathSegments.indexOf('receipt-images');
      const filePath = pathSegments.slice(bucketIndex + 1).join('/');

      // Supabase Storage에서 다운로드
      const { data, error } = await supabase.storage
        .from('receipt-images')
        .download(filePath);

      if (error) throw error;

      // Blob을 다운로드 가능한 URL로 변환
      const blob = new Blob([data], { type: 'image/jpeg' });
      const downloadUrl = window.URL.createObjectURL(blob);

      // 다운로드 트리거
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `영수증_${itemName}_${itemId}.jpg`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      // 메모리 해제
      window.URL.revokeObjectURL(downloadUrl);

      alert('✅ 영수증 다운로드 완료');
    } catch (error) {
      console.error('영수증 다운로드 오류:', error);
      alert(`❌ 다운로드 실패: ${error}`);
    } finally {
      setIsLoading(false);
    }
  };

  /**
   * 영수증 새 탭에서 보기
   */
  const handleViewInNewTab = () => {
    if (!receiptUrl) return;
    window.open(receiptUrl, '_blank');
  };

  // 영수증이 없는 경우
  if (!receiptUrl) {
    return (
      <span style={{ color: '#8E8E93', fontSize: '14px' }}>
        영수증 없음
      </span>
    );
  }

  // 영수증이 있는 경우
  return (
    <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
      {/* 보기 버튼 */}
      <button
        onClick={handleViewInNewTab}
        style={{
          padding: '6px 12px',
          backgroundColor: '#007AFF',
          color: 'white',
          border: 'none',
          borderRadius: '6px',
          cursor: 'pointer',
          fontSize: '14px',
          fontWeight: '600',
        }}
        title="영수증 보기"
      >
        📄 보기
      </button>

      {/* 다운로드 버튼 */}
      <button
        onClick={handleDownload}
        disabled={isLoading}
        style={{
          padding: '6px 12px',
          backgroundColor: '#34C759',
          color: 'white',
          border: 'none',
          borderRadius: '6px',
          cursor: isLoading ? 'not-allowed' : 'pointer',
          fontSize: '14px',
          fontWeight: '600',
          opacity: isLoading ? 0.6 : 1,
        }}
        title="영수증 다운로드"
      >
        {isLoading ? '⏳ 다운로드 중...' : '💾 다운로드'}
      </button>
    </div>
  );
};

/**
 * 사용 예시:
 * 
 * import { ReceiptDownloadButton } from './components/ReceiptDownloadButton';
 * 
 * <ReceiptDownloadButton
 *   itemId={item.id}
 *   receiptUrl={item.receipt_image_url}
 *   itemName={item.item_name}
 * />
 */



