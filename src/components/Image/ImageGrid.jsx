import { useState } from 'react';
import { apiEndpoints } from '../../config/api';
import './ImageGrid.css';

function ImageGrid({ images, onImageClick, onDeleteImage }) {
  const [menuOpen, setMenuOpen] = useState(null);

  const handleMenuToggle = (e, imageId) => {
    e.stopPropagation();
    setMenuOpen(menuOpen === imageId ? null : imageId);
  };

  const handleDelete = (e, imageId) => {
    e.stopPropagation();
    setMenuOpen(null);
    if (onDeleteImage) {
      onDeleteImage(imageId);
    }
  };

  const handleDownload = async (e, image) => {
    e.stopPropagation();
    setMenuOpen(null);
    
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

  const handleClickOutside = () => {
    setMenuOpen(null);
  };

  return (
    <div className="image-grid" onClick={handleClickOutside}>
      {images.map((image, index) => (
        <div 
          key={image.id} 
          className={`image-item fade-in stagger-${(index % 6) + 1}`}
        >
          <div 
            className="image-card"
            onClick={() => onImageClick(image)}
          >
            <div className="image-wrapper">
              <img 
                src={image.url} 
                alt={image.name}
                loading="lazy"
              />
            </div>
          </div>
          
          {onDeleteImage && (
            <div className="image-menu-container">
              <button 
                className="image-menu-btn"
                onClick={(e) => handleMenuToggle(e, image.id)}
                aria-label="메뉴 열기"
              >
                <span className="menu-dot"></span>
                <span className="menu-dot"></span>
                <span className="menu-dot"></span>
              </button>
              
              {menuOpen === image.id && (
                <div className="image-menu scale-in">
                  <button 
                    className="menu-item"
                    onClick={(e) => handleDownload(e, image)}
                  >
                    <span className="menu-icon">⬇️</span>
                    다운로드
                  </button>
                  <button 
                    className="menu-item danger"
                    onClick={(e) => handleDelete(e, image.id)}
                  >
                    <span className="menu-icon">🗑</span>
                    사진 삭제
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

export default ImageGrid;
