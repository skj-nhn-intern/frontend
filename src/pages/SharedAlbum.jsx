import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { apiEndpoints } from '../config/api';
import Layout from '../components/Layout/Layout';
import ImageGrid from '../components/Image/ImageGrid';
import ImageModal from '../components/Image/ImageModal';
import './SharedAlbum.css';

function SharedAlbum() {
  const { shareLink } = useParams();
  const { setInvitedMode, clearInvitedMode, isAuthenticated } = useAuth();
  
  const [album, setAlbum] = useState(null);
  const [selectedImage, setSelectedImage] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let isMounted = true;
    
    const fetchSharedAlbum = async () => {
      setLoading(true);
      setError(null);
      
      try {
        const url = apiEndpoints.share(shareLink);
        console.log('Fetching shared album from:', url);
        
        const response = await fetch(url);
        console.log('Response status:', response.status, response.statusText);
        
        if (!isMounted) return;
        
        if (response.ok) {
          const data = await response.json();
          console.log('Shared album data:', data);
          
          // 백엔드 응답을 프론트엔드 형식으로 변환
          // SharedAlbumResponse: album_name, album_description, photos, created_at
          const albumData = {
            id: shareLink, // shareLink를 ID로 사용 (앨범 ID는 백엔드에서 제공하지 않음)
            name: data.album_name,
            description: data.album_description || '',
            createdAt: data.created_at ? new Date(data.created_at).toLocaleDateString('ko-KR') : '',
            images: (data.photos || []).map((photo, index) => ({
              id: photo.id?.toString() || `photo-${index}`,
              name: photo.title || '',
              description: photo.description || '',
              url: photo.url || '',
              createdAt: photo.created_at ? new Date(photo.created_at).toLocaleDateString('ko-KR') : '',
            })),
          };
          
          if (!isMounted) return;
          
          setAlbum(albumData);
          
          // 인증되지 않은 사용자는 초대 모드로 설정 (한 번만)
          const token = localStorage.getItem('access_token');
          if (!token) {
            setInvitedMode(shareLink);
          }
        } else {
          const errorData = await response.json().catch(() => ({ detail: 'Unknown error' }));
          console.error('Error response:', response.status, errorData);
          
          if (!isMounted) return;
          
          if (response.status === 404) {
            setError('notfound');
          } else if (response.status === 410) {
            setError('expired');
          } else {
            setError('unknown');
          }
        }
      } catch (err) {
        console.error('Failed to fetch shared album:', err);
        console.error('Error details:', err.message, err.stack);
        
        if (!isMounted) return;
        setError('network');
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchSharedAlbum();
    
    return () => {
      isMounted = false;
    };
  }, [shareLink, setInvitedMode]);

  // 로딩 상태
  if (loading) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner"></div>
      </div>
    );
  }

  // 에러 상태
  if (error) {
    const errorMessages = {
      notfound: {
        icon: '🔗',
        title: '링크를 찾을 수 없습니다',
        description: '유효하지 않은 공유 링크이거나, 링크가 삭제되었을 수 있습니다.',
      },
      expired: {
        icon: '⏰',
        title: '링크가 만료되었습니다',
        description: '이 공유 링크는 만료되었거나 비활성화되었습니다.',
      },
      network: {
        icon: '🌐',
        title: '연결할 수 없습니다',
        description: '서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.',
      },
      unknown: {
        icon: '❌',
        title: '오류가 발생했습니다',
        description: '앨범을 불러오는 중 오류가 발생했습니다.',
      },
    };

    const { icon, title, description } = errorMessages[error] || errorMessages.unknown;

    return (
      <div className="shared-album-error">
        <div className="error-content fade-in">
          <div className="error-icon">{icon}</div>
          <h1>{title}</h1>
          <p>{description}</p>
          <div className="error-actions">
            <button 
              onClick={() => window.location.reload()} 
              className="btn btn-secondary"
            >
              다시 시도
            </button>
            <Link to="/login" className="btn btn-primary">
              로그인하기
            </Link>
          </div>
        </div>
      </div>
    );
  }

  if (!album) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner"></div>
      </div>
    );
  }

  return (
    <Layout>
      <div className="shared-album-page">
        <div className="shared-notice fade-in">
          <span className="notice-icon">👁</span>
          <span>공유 링크로 접속하셨습니다. 앨범을 보기만 할 수 있습니다.</span>
        </div>
        
        <div className="album-header fade-in stagger-1">
          <div className="album-header-content">
            <h1>{album.name}</h1>
            {album.description && (
              <p className="album-description">{album.description}</p>
            )}
            <div className="album-info">
              <span className="info-item">
                <span className="info-icon">📷</span>
                {album.images.length}장의 사진
              </span>
              <span className="info-item">
                <span className="info-icon">📅</span>
                {album.createdAt}
              </span>
            </div>
          </div>
        </div>

        <div className="album-content fade-in stagger-2">
          {album.images.length === 0 ? (
            <div className="empty-images">
              <div className="empty-icon">🖼</div>
              <h3>아직 사진이 없습니다</h3>
              <p>앨범 소유자가 사진을 추가하면 여기에 표시됩니다.</p>
            </div>
          ) : (
            <ImageGrid 
              images={album.images}
              onImageClick={setSelectedImage}
              onDeleteImage={null}
            />
          )}
        </div>

        {selectedImage && (
          <ImageModal 
            image={selectedImage}
            onClose={() => setSelectedImage(null)}
          />
        )}
      </div>
    </Layout>
  );
}

export default SharedAlbum;
