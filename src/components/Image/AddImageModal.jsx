import { useState, useEffect, useRef } from 'react';
import { useAlbums } from '../../contexts/AlbumContext';
import './AddImageModal.css';

function AddImageModal({ albumId, onClose, onImageAdded }) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [previewUrl, setPreviewUrl] = useState('');
  const [selectedFile, setSelectedFile] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  
  const { addImage } = useAlbums();
  const fileInputRef = useRef(null);

  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = '';
    };
  }, []);

  const handleFileSelect = (e) => {
    const file = e.target.files[0];
    if (file) {
      setSelectedFile(file);
      // 파일을 Data URL로 변환하여 미리보기
      const reader = new FileReader();
      reader.onload = (event) => {
        const dataUrl = event.target.result;
        setPreviewUrl(dataUrl);
        setImageUrl(''); // URL 입력 초기화
      };
      reader.readAsDataURL(file);
    }
  };

  const handleUrlChange = (e) => {
    const url = e.target.value;
    setImageUrl(url);
    setPreviewUrl(url);
    setSelectedFile(null); // 파일 선택 초기화
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    if (!name.trim()) {
      setError('사진 이름을 입력해주세요.');
      return;
    }
    
    if (!imageUrl && !selectedFile) {
      setError('사진을 선택하거나 URL을 입력해주세요.');
      return;
    }
    
    setIsLoading(true);
    
    try {
      await addImage(albumId, {
        name: name.trim(),
        description: description.trim(),
        url: imageUrl, // previewUrl은 Data URL이므로 전달하지 않음
        file: selectedFile,
      });
      
      if (onImageAdded) {
        onImageAdded();
      } else {
        onClose();
      }
    } catch (err) {
      // 에러 객체를 문자열로 변환
      let errorMessage = '사진 추가에 실패했습니다.';
      
      if (err && typeof err === 'object') {
        // Error 객체인 경우
        if (err.message) {
          errorMessage = err.message;
        } else if (err.detail) {
          errorMessage = err.detail;
        } else {
          // 객체를 문자열로 변환 시도
          try {
            errorMessage = JSON.stringify(err);
          } catch (e) {
            errorMessage = '사진 추가에 실패했습니다.';
          }
        }
      } else if (typeof err === 'string') {
        errorMessage = err;
      }
      
      // URL이나 내부 경로가 포함된 메시지는 일반 메시지로 대체
      const safeMessage = errorMessage.includes('http://') || errorMessage.includes('https://') || errorMessage.includes('url')
        ? '사진 추가에 실패했습니다. 잠시 후 다시 시도해주세요.'
        : errorMessage;
      setError(safeMessage);
    } finally {
      setIsLoading(false);
    }
  };

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  return (
    <div className="add-image-overlay" onClick={handleBackdropClick}>
      <div className="add-image-modal scale-in">
        <div className="modal-header">
          <h2>사진 추가</h2>
          <button className="modal-close-btn" onClick={onClose}>
            ✕
          </button>
        </div>
        
        <form className="add-image-form" onSubmit={handleSubmit}>
          {error && (
            <div className="form-error scale-in">
              <span className="error-icon">!</span>
              {error}
            </div>
          )}
          
          <div className="upload-section">
            <div 
              className={`upload-area ${previewUrl ? 'has-preview' : ''}`}
              onClick={() => fileInputRef.current?.click()}
            >
              {previewUrl ? (
                <img src={previewUrl} alt="미리보기" className="preview-image" />
              ) : (
                <div className="upload-placeholder">
                  <span className="upload-icon">📷</span>
                  <span className="upload-text">클릭하여 사진 선택</span>
                  <span className="upload-hint">또는 아래에 URL 입력</span>
                </div>
              )}
            </div>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              onChange={handleFileSelect}
              className="file-input"
            />
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="imageUrl">
              이미지 URL <span className="optional">(선택)</span>
            </label>
            <input
              id="imageUrl"
              type="url"
              className="form-input"
              placeholder="https://example.com/image.jpg"
              value={imageUrl}
              onChange={handleUrlChange}
            />
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="imageName">
              사진 이름 <span className="required">*</span>
            </label>
            <input
              id="imageName"
              type="text"
              className="form-input"
              placeholder="예: 해변 일출"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={50}
            />
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="imageDesc">
              설명 <span className="optional">(선택)</span>
            </label>
            <textarea
              id="imageDesc"
              className="form-input form-textarea"
              placeholder="사진에 대한 설명을 적어주세요"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              maxLength={200}
            />
          </div>
          
          <div className="form-actions">
            <button 
              type="button" 
              className="btn btn-secondary"
              onClick={onClose}
            >
              취소
            </button>
            <button 
              type="submit" 
              className="btn btn-primary"
              disabled={isLoading}
            >
              {isLoading ? '추가 중...' : '사진 추가'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default AddImageModal;
