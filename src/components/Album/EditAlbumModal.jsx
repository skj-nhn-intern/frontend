import { useState, useEffect } from 'react';
import './EditAlbumModal.css';

function EditAlbumModal({ album, onClose, onUpdate }) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (album) {
      setName(album.name || '');
      setDescription(album.description || '');
    }
  }, [album]);

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

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    if (!name.trim()) {
      setError('앨범 이름을 입력해주세요.');
      return;
    }
    
    setIsLoading(true);
    
    try {
      await onUpdate({
        name: name.trim(),
        description: description.trim() || '',
      });
      onClose();
    } catch (err) {
      setError(err.message || '앨범 수정에 실패했습니다.');
      setIsLoading(false);
    }
  };

  if (!album) return null;

  return (
    <div className="edit-album-modal-overlay" onClick={handleBackdropClick}>
      <div className="edit-album-modal scale-in">
        <div className="edit-album-header">
          <div className="edit-album-icon">✏️</div>
          <h2>앨범 수정</h2>
          <button 
            className="modal-close-btn"
            onClick={onClose}
            aria-label="닫기"
          >
            ×
          </button>
        </div>
        
        <form className="edit-album-form" onSubmit={handleSubmit}>
          {error && (
            <div className="form-error scale-in">
              <span className="error-icon">!</span>
              {error}
            </div>
          )}
          
          <div className="form-group">
            <label className="form-label" htmlFor="edit-name">
              앨범 이름 <span className="required">*</span>
            </label>
            <input
              id="edit-name"
              type="text"
              className="form-input"
              placeholder="예: 여름 휴가 2025"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={255}
              disabled={isLoading}
            />
            <span className="form-hint">{name.length}/255</span>
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="edit-description">
              설명 <span className="optional">(선택)</span>
            </label>
            <textarea
              id="edit-description"
              className="form-input form-textarea"
              placeholder="앨범에 대한 간단한 설명을 적어주세요"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              maxLength={500}
              disabled={isLoading}
            />
            <span className="form-hint">{description.length}/500</span>
          </div>
          
          <div className="form-actions">
            <button 
              type="button"
              className="btn btn-secondary"
              onClick={onClose}
              disabled={isLoading}
            >
              취소
            </button>
            <button 
              type="submit" 
              className="btn btn-primary"
              disabled={isLoading}
            >
              {isLoading ? '수정 중...' : '수정 완료'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default EditAlbumModal;
