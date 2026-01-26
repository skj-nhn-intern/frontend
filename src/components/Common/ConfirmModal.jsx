import { useEffect } from 'react';
import './ConfirmModal.css';

function ConfirmModal({ 
  title, 
  message, 
  confirmText = '확인', 
  cancelText = '취소', 
  onConfirm, 
  onCancel,
  isDanger = false 
}) {
  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape') {
        onCancel();
      }
    };
    
    document.addEventListener('keydown', handleEscape);
    document.body.style.overflow = 'hidden';
    
    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [onCancel]);

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onCancel();
    }
  };

  return (
    <div className="confirm-modal-overlay" onClick={handleBackdropClick}>
      <div className="confirm-modal scale-in">
        <div className="confirm-icon">
          {isDanger ? '⚠️' : 'ℹ️'}
        </div>
        
        <h3 className="confirm-title">{title}</h3>
        <p className="confirm-message">{message}</p>
        
        <div className="confirm-actions">
          <button 
            className="btn btn-secondary"
            onClick={onCancel}
          >
            {cancelText}
          </button>
          <button 
            className={`btn ${isDanger ? 'btn-danger' : 'btn-primary'}`}
            onClick={onConfirm}
          >
            {confirmText}
          </button>
        </div>
      </div>
    </div>
  );
}

export default ConfirmModal;
