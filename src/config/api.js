/**
 * API Configuration
 * 
 * 백엔드 API URL을 환경 변수 또는 기본값으로 관리합니다.
 * 
 * 환경 변수 우선순위:
 * 1. import.meta.env.VITE_API_BASE_URL (Vite 환경 변수)
 * 2. window.APP_CONFIG?.apiBaseUrl (런타임 설정)
 * 3. 기본값: http://localhost:8000
 * 
 * 프로덕션 배포 시:
 * - nginx를 통해 /api 경로로 프록시 설정
 * - VITE_API_BASE_URL을 빌드 시 설정하거나
 * - window.APP_CONFIG를 통해 런타임에 설정
 */

// Vite 환경 변수에서 API URL 가져오기
const getApiBaseUrl = () => {
  // 1. Vite 환경 변수 확인 (빌드 시 설정)
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }

  // 2. 런타임 설정 확인 (window.APP_CONFIG)
  if (typeof window !== 'undefined' && window.APP_CONFIG?.apiBaseUrl) {
    return window.APP_CONFIG.apiBaseUrl;
  }

  // 3. 개발 환경 기본값
  if (import.meta.env.DEV) {
    return 'http://localhost:8000';
  }

  // 4. 프로덕션 기본값 (nginx 프록시 사용)
  return '/api';
};

export const API_BASE_URL = getApiBaseUrl();

/**
 * API 엔드포인트 헬퍼 함수
 */
export const apiEndpoints = {
  // Auth
  register: () => `${API_BASE_URL}/auth/register`,
  login: () => `${API_BASE_URL}/auth/login`,
  me: () => `${API_BASE_URL}/auth/me`,
  
  // Albums
  albums: () => `${API_BASE_URL}/albums/`,
  album: (id) => `${API_BASE_URL}/albums/${id}`,
  albumShare: (id) => `${API_BASE_URL}/albums/${id}/share`,
  
  // Photos
  photos: () => `${API_BASE_URL}/photos/`,
  photo: (id) => `${API_BASE_URL}/photos/${id}`,
  
  // Share
  share: (token) => `${API_BASE_URL}/share/${token}`,
};

/**
 * API 요청 헬퍼 함수
 */
export const apiRequest = async (url, options = {}) => {
  const token = localStorage.getItem('access_token');
  
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: '요청 처리 중 오류가 발생했습니다.' }));
    // 내부 정보 노출 방지: 사용자 친화적인 메시지만 반환
    const userFriendlyMessage = error.detail || '요청 처리 중 오류가 발생했습니다.';
    throw new Error(userFriendlyMessage);
  }

  return response.json();
};

// 개발 환경에서 API URL 로그 출력
if (import.meta.env.DEV) {
  console.log('API Base URL:', API_BASE_URL);
}

