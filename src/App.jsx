import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { AlbumProvider } from './contexts/AlbumContext';
import Layout from './components/Layout/Layout';
import Login from './pages/Login';
import Register from './pages/Register';
import AlbumList from './pages/AlbumList';
import AlbumDetail from './pages/AlbumDetail';
import AddAlbum from './pages/AddAlbum';
import SharedAlbum from './pages/SharedAlbum';

function ProtectedRoute({ children }) {
  const { isAuthenticated, isLoading, isInvitedUser, clearInvitedMode } = useAuth();
  
  // ProtectedRoute는 인증된 사용자만 접근 가능하므로 invitedMode 해제
  React.useEffect(() => {
    if (isInvitedUser) {
      clearInvitedMode();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // 마운트 시 한 번만 실행
  
  if (isLoading) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner"></div>
      </div>
    );
  }
  
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  
  return children;
}

function PublicRoute({ children }) {
  const { isAuthenticated, isLoading } = useAuth();
  
  if (isLoading) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner"></div>
      </div>
    );
  }
  
  if (isAuthenticated) {
    return <Navigate to="/albums" replace />;
  }
  
  return children;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/albums" replace />} />
      
      <Route path="/login" element={
        <PublicRoute>
          <Login />
        </PublicRoute>
      } />
      
      <Route path="/register" element={
        <PublicRoute>
          <Register />
        </PublicRoute>
      } />
      
      <Route path="/albums" element={
        <ProtectedRoute>
          <Layout>
            <AlbumList />
          </Layout>
        </ProtectedRoute>
      } />
      
      <Route path="/albums/new" element={
        <ProtectedRoute>
          <Layout>
            <AddAlbum />
          </Layout>
        </ProtectedRoute>
      } />
      
      <Route path="/albums/:albumId" element={
        <ProtectedRoute>
          <Layout>
            <AlbumDetail />
          </Layout>
        </ProtectedRoute>
      } />
      
      {/* 공유 링크로 접근하는 라우트 */}
      <Route path="/share/:shareLink" element={<SharedAlbum />} />
      
      <Route path="*" element={<Navigate to="/albums" replace />} />
    </Routes>
  );
}

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AlbumProvider>
          <AppRoutes />
        </AlbumProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
