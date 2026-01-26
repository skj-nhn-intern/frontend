import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAlbums } from '../contexts/AlbumContext';
import './AddAlbum.css';

function AddAlbum() {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  
  const { addAlbum } = useAlbums();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    if (!name.trim()) {
      setError('앨범 이름을 입력해주세요.');
      return;
    }
    
    setIsLoading(true);
    
    try {
      const newAlbum = await addAlbum({
        name: name.trim(),
        description: description.trim(),
      });
      
      navigate(`/albums/${newAlbum.id}`);
    } catch (err) {
      setError(err.message || '앨범 생성에 실패했습니다.');
      setIsLoading(false);
    }
  };

  return (
    <div className="add-album-page">
      <div className="page-breadcrumb fade-in">
        <Link to="/albums" className="breadcrumb-link">← 앨범 목록</Link>
      </div>
      
      <div className="add-album-container fade-in stagger-1">
        <div className="add-album-header">
          <div className="add-album-icon">📷</div>
          <h1>새 앨범 만들기</h1>
          <p>소중한 순간들을 담을 새로운 앨범을 만들어보세요</p>
        </div>
        
        <form className="add-album-form" onSubmit={handleSubmit}>
          {error && (
            <div className="form-error scale-in">
              <span className="error-icon">!</span>
              {error}
            </div>
          )}
          
          <div className="form-group">
            <label className="form-label" htmlFor="name">
              앨범 이름 <span className="required">*</span>
            </label>
            <input
              id="name"
              type="text"
              className="form-input"
              placeholder="예: 여름 휴가 2025"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={50}
            />
            <span className="form-hint">{name.length}/50</span>
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="description">
              설명 <span className="optional">(선택)</span>
            </label>
            <textarea
              id="description"
              className="form-input form-textarea"
              placeholder="앨범에 대한 간단한 설명을 적어주세요"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              maxLength={200}
            />
            <span className="form-hint">{description.length}/200</span>
          </div>
          
          <div className="form-actions">
            <Link to="/albums" className="btn btn-secondary">
              취소
            </Link>
            <button 
              type="submit" 
              className="btn btn-primary"
              disabled={isLoading}
            >
              {isLoading ? '생성 중...' : '앨범 만들기'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default AddAlbum;
