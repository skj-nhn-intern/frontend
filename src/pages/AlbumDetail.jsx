import { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useAlbums } from '../contexts/AlbumContext';
import { useAuth } from '../contexts/AuthContext';
import ImageGrid from '../components/Image/ImageGrid';
import ImageModal from '../components/Image/ImageModal';
import AddImageModal from '../components/Image/AddImageModal';
import ShareLinkPanel from '../components/ShareLink/ShareLinkPanel';
import ConfirmModal from '../components/Common/ConfirmModal';
import EditAlbumModal from '../components/Album/EditAlbumModal';
import './AlbumDetail.css';

function AlbumDetail() {
  const { albumId } = useParams();
  const navigate = useNavigate();
  const { getAlbum, updateAlbum, deleteAlbum, deleteImage } = useAlbums();
  const { isAuthenticated, isInvitedUser } = useAuth();
  
  const [album, setAlbum] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedImage, setSelectedImage] = useState(null);
  const [showAddImage, setShowAddImage] = useState(false);
  const [showSharePanel, setShowSharePanel] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [imageToDelete, setImageToDelete] = useState(null);

  const loadAlbum = useCallback(async () => {
    setLoading(true);
    try {
      const albumData = await getAlbum(albumId);
      if (albumData) {
        setAlbum(albumData);
      } else {
        navigate('/albums');
      }
    } catch (error) {
      console.error('Failed to load album:', error);
      navigate('/albums');
    } finally {
      setLoading(false);
    }
  }, [albumId, getAlbum, navigate]);

  useEffect(() => {
    loadAlbum();
  }, [loadAlbum]);

  if (loading) {
    return (
      <div className="loading-state">
        <div className="loading-spinner"></div>
      </div>
    );
  }

  if (!album) {
    return (
      <div className="loading-state">
        <div className="loading-spinner"></div>
      </div>
    );
  }

  const handleDeleteAlbum = async () => {
    try {
      await deleteAlbum(album.id);
      navigate('/albums');
    } catch (error) {
      console.error('Failed to delete album:', error);
      alert('앨범 삭제에 실패했습니다.');
    }
  };

  const handleDeleteImage = (imageId) => {
    setImageToDelete(imageId);
  };

  const confirmDeleteImage = async () => {
    if (imageToDelete) {
      try {
        await deleteImage(album.id, imageToDelete);
        // 앨범 다시 로드
        await loadAlbum();
      } catch (error) {
        console.error('Failed to delete image:', error);
        alert('사진 삭제에 실패했습니다.');
      }
      setImageToDelete(null);
    }
  };

  const handleImageAdded = () => {
    setShowAddImage(false);
    loadAlbum();
  };

  const handleShareLinkChanged = () => {
    loadAlbum();
  };

  const handleUpdateAlbum = async (albumData) => {
    try {
      await updateAlbum(album.id, albumData);
      // 앨범 다시 로드하여 최신 정보 반영
      await loadAlbum();
    } catch (error) {
      console.error('Failed to update album:', error);
      throw error;
    }
  };

  const canEdit = isAuthenticated && !isInvitedUser;

  return (
    <div className="album-detail-page">
      <div className="page-breadcrumb fade-in">
        <Link to="/albums" className="breadcrumb-link">← 앨범 목록</Link>
      </div>
      
      <div className="album-header fade-in stagger-1">
        <div className="album-header-content">
          <div className="album-title-row">
            <h1>{album.name}</h1>
            {album.shareLink && (
              <span className="shared-badge">🔗 공유 중</span>
            )}
          </div>
          {album.description && (
            <p className="album-description">{album.description}</p>
          )}
          <div className="album-info">
            <span className="info-item">
              <span className="info-icon">📷</span>
              {album.images ? album.images.length : 0}장의 사진
            </span>
            <span className="info-item">
              <span className="info-icon">📅</span>
              {album.createdAt}
            </span>
          </div>
        </div>
        
        {canEdit && (
          <div className="album-actions">
            <button 
              className="btn btn-secondary"
              onClick={() => setShowEditModal(true)}
            >
              <span className="btn-icon">✏️</span>
              앨범 수정
            </button>
            <button 
              className="btn btn-secondary"
              onClick={() => setShowSharePanel(true)}
            >
              <span className="btn-icon">🔗</span>
              공유 링크
            </button>
            <button 
              className="btn btn-primary"
              onClick={() => setShowAddImage(true)}
            >
              <span className="btn-icon">+</span>
              사진 추가
            </button>
            <button 
              className="btn btn-danger"
              onClick={() => setShowDeleteConfirm(true)}
            >
              <span className="btn-icon">🗑</span>
              앨범 삭제
            </button>
          </div>
        )}
      </div>

      <div className="album-content fade-in stagger-2">
        {!album.images || album.images.length === 0 ? (
          <div className="empty-images">
            <div className="empty-icon">🖼</div>
            <h3>아직 사진이 없습니다</h3>
            <p>첫 번째 사진을 추가해보세요</p>
            {canEdit && (
              <button 
                className="btn btn-primary"
                onClick={() => setShowAddImage(true)}
              >
                사진 추가하기
              </button>
            )}
          </div>
        ) : (
          <ImageGrid 
            images={album.images}
            onImageClick={setSelectedImage}
            onDeleteImage={canEdit ? handleDeleteImage : null}
          />
        )}
      </div>

      {/* 이미지 상세 모달 */}
      {selectedImage && (
        <ImageModal 
          image={selectedImage}
          onClose={() => setSelectedImage(null)}
        />
      )}

      {/* 이미지 추가 모달 */}
      {showAddImage && (
        <AddImageModal 
          albumId={album.id}
          onClose={() => setShowAddImage(false)}
          onImageAdded={handleImageAdded}
        />
      )}

      {/* 공유 링크 패널 */}
      {showSharePanel && (
        <ShareLinkPanel 
          album={album}
          onClose={() => setShowSharePanel(false)}
          onShareLinkChanged={handleShareLinkChanged}
        />
      )}

      {/* 앨범 수정 모달 */}
      {showEditModal && (
        <EditAlbumModal
          album={album}
          onClose={() => setShowEditModal(false)}
          onUpdate={handleUpdateAlbum}
        />
      )}

      {/* 앨범 삭제 확인 모달 */}
      {showDeleteConfirm && (
        <ConfirmModal
          title="앨범 삭제"
          message="삭제하시겠습니까? 이 작업은 되돌릴 수 없으며, 앨범의 모든 사진도 함께 삭제됩니다."
          confirmText="삭제"
          cancelText="취소"
          onConfirm={handleDeleteAlbum}
          onCancel={() => setShowDeleteConfirm(false)}
          isDanger
        />
      )}

      {/* 이미지 삭제 확인 모달 */}
      {imageToDelete && (
        <ConfirmModal
          title="사진 삭제"
          message="삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다."
          confirmText="삭제"
          cancelText="취소"
          onConfirm={confirmDeleteImage}
          onCancel={() => setImageToDelete(null)}
          isDanger
        />
      )}
    </div>
  );
}

export default AlbumDetail;
