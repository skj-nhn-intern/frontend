import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAlbums } from '../contexts/AlbumContext';
import './AlbumList.css';

function AlbumList() {
  const { albums, loading, fetchAlbums } = useAlbums();

  useEffect(() => {
    fetchAlbums();
  }, [fetchAlbums]);

  if (loading) {
    return (
      <div className="album-list-page">
        <div className="loading-state">
          <div className="loading-spinner"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="album-list-page">
      <div className="page-header fade-in">
        <div className="page-header-content">
          <h1>내 앨범</h1>
          <p>소중한 순간들을 앨범으로 정리하세요</p>
        </div>
        <Link to="/albums/new" className="btn btn-primary">
          <span className="btn-icon">+</span>
          새 앨범 만들기
        </Link>
      </div>

      {albums.length === 0 ? (
        <div className="empty-state fade-in stagger-1">
          <div className="empty-icon">📷</div>
          <h3>아직 앨범이 없습니다</h3>
          <p>첫 번째 앨범을 만들어 소중한 순간을 기록해보세요</p>
          <Link to="/albums/new" className="btn btn-primary">
            앨범 만들기
          </Link>
        </div>
      ) : (
        <div className="album-grid">
          {albums.map((album, index) => (
            <Link 
              key={album.id} 
              to={`/albums/${album.id}`}
              className={`album-card card fade-in stagger-${(index % 6) + 1}`}
            >
              <div className="album-card-content">
                <div className="album-icon">
                  <span>{album.name.charAt(0)}</span>
                </div>
                <h3 className="album-name">{album.name}</h3>
                <div className="album-meta">
                  <span className="album-count">
                    {album.photoCount || (album.images ? album.images.length : 0)}장의 사진
                  </span>
                  <span className="album-date">{album.createdAt}</span>
                </div>
                {album.shareLink && (
                  <div className="album-shared-badge">
                    <span>🔗</span> 공유 중
                  </div>
                )}
              </div>
              <div className="album-card-arrow">→</div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

export default AlbumList;
