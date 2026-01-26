import { useEffect } from 'react';
import { apiEndpoints } from '../../config/api';
import './ImageModal.css';

function ImageModal({ image, onClose }) {
  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    
    document.addEventListener('keydown', handleEscape);
    document.body.style.overflow = 'hidden';
    
    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  const handleDownload = async () => {
    try {
      // CDN URL을 직접 사용하여 다운로드 (더 효율적)
      if (!image.url) {
        throw new Error('이미지 URL이 없습니다.');
      }

      // CDN URL에서 파일 다운로드
      // Auth Token이 이미 URL에 ?token=... 형식으로 포함되어 있음
      const response = await fetch(image.url, {
        method: 'GET',
        mode: 'cors',
        // CDN Auth Token은 URL 쿼리 파라미터로 포함되므로 별도 헤더 불필요
      });

      if (!response.ok) {
        // CDN 다운로드 실패 시 백엔드 엔드포인트로 fallback
        const token = localStorage.getItem('access_token');
        const fallbackResponse = await fetch(apiEndpoints.photo(image.id) + '/download', {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        });

        if (!fallbackResponse.ok) {
          throw new Error('다운로드에 실패했습니다.');
        }

        const blob = await fallbackResponse.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        
        // 파일명 추출
        const contentDisposition = fallbackResponse.headers.get('Content-Disposition');
        let filename = image.name || 'photo';
        if (contentDisposition) {
          const filenameMatch = contentDisposition.match(/filename="?(.+)"?/i);
          if (filenameMatch) {
            filename = filenameMatch[1];
          }
        }
        
        // 확장자 추가
        if (!filename.includes('.')) {
          const contentType = fallbackResponse.headers.get('Content-Type');
          const extMap = {
            'image/jpeg': '.jpg',
            'image/png': '.png',
            'image/gif': '.gif',
            'image/webp': '.webp',
            'image/heic': '.heic',
          };
          const ext = extMap[contentType] || '.jpg';
          filename += ext;
        }
        
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
        return;
      }

      // CDN에서 다운로드 성공
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      
      // 파일명 설정
      let filename = image.name || 'photo';
      
      // 확장자 추가
      if (!filename.includes('.')) {
        const contentType = response.headers.get('Content-Type');
        const extMap = {
          'image/jpeg': '.jpg',
          'image/png': '.png',
          'image/gif': '.gif',
          'image/webp': '.webp',
          'image/heic': '.heic',
        };
        const ext = extMap[contentType] || '.jpg';
        filename += ext;
      }
      
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Download failed:', error);
      alert('다운로드에 실패했습니다.');
    }
  };

  return (
    <div className="image-modal-overlay" onClick={handleBackdropClick}>
      <div className="image-modal scale-in">
        <button className="modal-close-btn" onClick={onClose}>
          ✕
        </button>
        
        <div className="modal-content">
          <div className="modal-image-container">
            <img src={image.url} alt={image.name} />
          </div>
          
          <div className="modal-info">
            <h2 className="image-name">{image.name}</h2>
            {image.description && (
              <p className="image-description">{image.description}</p>
            )}
            <div className="image-meta">
              <span className="meta-item">
                <span className="meta-icon">📅</span>
                {image.createdAt}
              </span>
            </div>
            <div className="modal-actions">
              <button 
                className="btn btn-primary"
                onClick={handleDownload}
              >
                <span className="btn-icon">⬇️</span>
                다운로드
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default ImageModal;
