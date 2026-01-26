import { useState, useEffect } from 'react';
import { useAlbums } from '../../contexts/AlbumContext';
import './ShareLinkPanel.css';

function ShareLinkPanel({ album, onClose, onShareLinkChanged }) {
  const [copied, setCopied] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const { createShareLink, deleteShareLink } = useAlbums();

  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = '';
    };
  }, []);

  // shareLink가 객체인 경우 토큰 추출
  const shareLinkToken = album.shareLink 
    ? (typeof album.shareLink === 'string' ? album.shareLink : album.shareLink.token || album.shareLink)
    : null;
  
  const shareUrl = shareLinkToken 
    ? `${window.location.origin}/share/${shareLinkToken}`
    : null;

  const handleCreateLink = async () => {
    setIsLoading(true);
    setError('');
    try {
      await createShareLink(album.id);
      if (onShareLinkChanged) onShareLinkChanged();
    } catch (err) {
      setError(err.message || '공유 링크 생성에 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDeleteLink = async () => {
    setIsLoading(true);
    setError('');
    try {
      await deleteShareLink(album.id);
      if (onShareLinkChanged) onShareLinkChanged();
    } catch (err) {
      setError(err.message || '공유 링크 삭제에 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopyLink = async () => {
    if (shareUrl) {
      try {
        await navigator.clipboard.writeText(shareUrl);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      } catch (err) {
        // 클립보드 API 실패 시 대체 방법
        const textArea = document.createElement('textarea');
        textArea.value = shareUrl;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      }
    }
  };

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  return (
    <div className="share-panel-overlay" onClick={handleBackdropClick}>
      <div className="share-panel scale-in">
        <div className="panel-header">
          <h2>
            <span className="panel-icon">🔗</span>
            공유 링크
          </h2>
          <button className="panel-close-btn" onClick={onClose}>
            ✕
          </button>
        </div>
        
        <div className="panel-content">
          {error && (
            <div className="share-error">
              <span className="error-icon">!</span>
              {error}
            </div>
          )}
          
          {shareLinkToken ? (
            <>
              <div className="share-status active">
                <span className="status-icon">✓</span>
                <span>공유 링크가 활성화되어 있습니다</span>
              </div>
              
              <div className="share-url-container">
                <input 
                  type="text" 
                  className="share-url-input"
                  value={shareUrl}
                  readOnly
                />
                <button 
                  className={`btn btn-primary copy-btn ${copied ? 'copied' : ''}`}
                  onClick={handleCopyLink}
                >
                  {copied ? '✓ 복사됨' : '복사'}
                </button>
              </div>
              
              <p className="share-info">
                이 링크를 통해 누구나 앨범의 사진을 볼 수 있습니다.
                <br />
                단, 사진을 추가하거나 삭제할 수는 없습니다.
              </p>
              
              <button 
                className="btn btn-danger delete-link-btn"
                onClick={handleDeleteLink}
                disabled={isLoading}
              >
                <span className="btn-icon">🗑</span>
                {isLoading ? '삭제 중...' : '공유 링크 삭제'}
              </button>
            </>
          ) : (
            <>
              <div className="share-status inactive">
                <span className="status-icon">○</span>
                <span>공유 링크가 없습니다</span>
              </div>
              
              <p className="share-info">
                공유 링크를 생성하면 링크를 통해 누구나 이 앨범을 볼 수 있습니다.
                <br />
                방문자는 사진을 보기만 할 수 있으며, 수정은 불가능합니다.
              </p>
              
              <button 
                className="btn btn-primary create-link-btn"
                onClick={handleCreateLink}
                disabled={isLoading}
              >
                <span className="btn-icon">+</span>
                {isLoading ? '생성 중...' : '공유 링크 생성'}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default ShareLinkPanel;
