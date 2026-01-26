import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import './Auth.css';

function Register() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  const { register } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    if (!name || !email || !password || !confirmPassword) {
      setError('모든 필드를 입력해주세요.');
      return;
    }
    
    if (password !== confirmPassword) {
      setError('비밀번호가 일치하지 않습니다.');
      return;
    }
    
    if (password.length < 8) {
      setError('비밀번호는 최소 8자 이상이어야 합니다.');
      return;
    }
    
    setIsLoading(true);
    
    try {
      await register(name, email, password);
      // 회원가입 성공 후 로그인 페이지로 이동
      navigate('/login');
    } catch (err) {
      setError(err.message || '회원가입에 실패했습니다.');
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
          <h1>Create Account</h1>
          <p>새로운 앨범 공간을 만들어보세요</p>
        </div>
        
        <form className="auth-form" onSubmit={handleSubmit}>
          {error && (
            <div className="auth-error scale-in">
              <span className="error-icon">!</span>
              {error}
            </div>
          )}
          
          <div className="form-group">
            <label className="form-label" htmlFor="name">이름</label>
            <input
              id="name"
              type="text"
              className="form-input"
              placeholder="홍길동"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoComplete="name"
            />
          </div>
          
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
              placeholder="최소 8자 이상"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="new-password"
            />
          </div>
          
          <div className="form-group">
            <label className="form-label" htmlFor="confirmPassword">비밀번호 확인</label>
            <input
              id="confirmPassword"
              type="password"
              className="form-input"
              placeholder="비밀번호를 다시 입력하세요"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              autoComplete="new-password"
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
                가입 중...
              </span>
            ) : '회원가입'}
          </button>
        </form>
        
        <div className="auth-footer">
          <p>
            이미 계정이 있으신가요?{' '}
            <Link to="/login" className="auth-link">로그인</Link>
          </p>
        </div>
      </div>
    </div>
  );
}

export default Register;
