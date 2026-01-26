import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import './Auth.css';

function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    if (!email || !password) {
      setError('이메일과 비밀번호를 입력해주세요.');
      return;
    }
    
    setIsLoading(true);
    
    try {
      await login(email, password);
      navigate('/albums');
    } catch (err) {
      setError(err.message || '이메일 또는 비밀번호가 올바르지 않습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-background">
        <div className="auth-bg-shape shape-1"></div>
        <div className="auth-bg-shape shape-2"></div>
        <div className="auth-bg-shape shape-3"></div>
      </div>
      
      <div className="auth-container fade-in">
        <div className="auth-header">
          <div className="auth-logo">◈</div>
          <h1>Welcome Back</h1>
          <p>앨범을 관리하고 소중한 순간을 공유하세요</p>
        </div>
        
        <form className="auth-form" onSubmit={handleSubmit}>
          {error && (
            <div className="auth-error scale-in">
              <span className="error-icon">!</span>
              {error}
            </div>
          )}
          
          <div className="form-group">
            <label className="form-label" htmlFor="email">이메일</label>
            <input
              id="email"
              type="email"
              className="form-input"
              placeholder="example@email.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
            />
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="password">비밀번호</label>
            <input
              id="password"
              type="password"
              className="form-input"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
            />
          </div>
          
          <button 
            type="submit" 
            className="btn btn-primary auth-btn"
            disabled={isLoading}
          >
            {isLoading ? (
              <span className="btn-loading">
                <span className="spinner"></span>
                로그인 중...
              </span>
            ) : '로그인'}
          </button>
        </form>
        
        <div className="auth-footer">
          <p>
            계정이 없으신가요?{' '}
            <Link to="/register" className="auth-link">회원가입</Link>
          </p>
        </div>
      </div>
    </div>
  );
}

export default Login;
