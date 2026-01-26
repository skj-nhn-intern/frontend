import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import './Layout.css';

function Layout({ children }) {
  const { user, logout, isInvitedUser } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="layout">
      <header className="header">
        <div className="header-container">
          <Link to="/albums" className="logo">
            <span className="logo-icon">◈</span>
            <span className="logo-text">Album</span>
          </Link>
          
          <nav className="nav">
            {!isInvitedUser && user && (
              <>
                <span className="user-greeting">
                  안녕하세요, <strong>{user.username}</strong>님
                </span>
                <button className="btn btn-ghost" onClick={handleLogout}>
                  로그아웃
                </button>
              </>
            )}
            {isInvitedUser && (
              <span className="guest-badge">
                <span className="guest-icon">👁</span>
                보기 전용
              </span>
            )}
          </nav>
        </div>
      </header>
      
      <main className="main">
        <div className="main-container">
          {children}
        </div>
      </main>
      
      <footer className="footer">
        <div className="footer-container">
          <p>© 2025 Album Sharing. Made with ♥</p>
        </div>
      </footer>
    </div>
  );
}

export default Layout;
