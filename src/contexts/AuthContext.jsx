import { createContext, useContext, useState, useEffect } from 'react';
import { apiEndpoints, apiRequest } from '../config/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isInvitedUser, setIsInvitedUser] = useState(false);

  useEffect(() => {
    // 저장된 토큰으로 사용자 정보 복원
    const restoreUser = async () => {
      const token = localStorage.getItem('access_token');
      const invitedMode = localStorage.getItem('invitedMode');
      
      // 토큰이 있으면 먼저 사용자 정보 복원 시도
      if (token) {
        try {
          const userData = await apiRequest(apiEndpoints.me());
          setUser(userData);
          setIsInvitedUser(false);
          // 사용자 정보 복원 성공 시 invitedMode 제거
          if (invitedMode === 'true') {
            localStorage.removeItem('invitedMode');
            localStorage.removeItem('invitedAlbumId');
          }
        } catch (error) {
          console.error('Failed to restore user:', error);
          localStorage.removeItem('access_token');
          // 토큰이 유효하지 않으면 invitedMode 확인
          if (invitedMode === 'true') {
            setIsInvitedUser(true);
          }
        }
      } else if (invitedMode === 'true') {
        // 토큰이 없고 invitedMode만 있는 경우
        setIsInvitedUser(true);
      }
      
      setIsLoading(false);
    };

    restoreUser();
  }, []);

  const register = async (name, email, password) => {
    const response = await fetch(apiEndpoints.register(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email,
        username: name,
        password,
      }),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: '회원가입에 실패했습니다.' }));
      throw new Error(error.detail || '회원가입에 실패했습니다.');
    }

    return await response.json();
  };

  const login = async (email, password) => {
    const response = await fetch(apiEndpoints.login(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: '로그인에 실패했습니다.' }));
      throw new Error(error.detail || '이메일 또는 비밀번호가 올바르지 않습니다.');
    }

    const tokenData = await response.json();
    localStorage.setItem('access_token', tokenData.access_token);
    
    // 사용자 정보 가져오기
    const userData = await apiRequest(apiEndpoints.me());
    setUser(userData);
    setIsInvitedUser(false);
    localStorage.removeItem('invitedMode');
    
    return userData;
  };

  const logout = () => {
    setUser(null);
    setIsInvitedUser(false);
    localStorage.removeItem('access_token');
    localStorage.removeItem('invitedMode');
  };

  const setInvitedMode = (albumId) => {
    setIsInvitedUser(true);
    setUser(null);
    localStorage.setItem('invitedMode', 'true');
    localStorage.setItem('invitedAlbumId', albumId);
    localStorage.removeItem('access_token');
  };

  const clearInvitedMode = () => {
    setIsInvitedUser(false);
    localStorage.removeItem('invitedMode');
    localStorage.removeItem('invitedAlbumId');
  };

  const isAuthenticated = !!user && !isInvitedUser;

  const value = {
    user,
    isLoading,
    isAuthenticated,
    isInvitedUser,
    register,
    login,
    logout,
    setInvitedMode,
    clearInvitedMode,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
