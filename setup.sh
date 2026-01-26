#!/bin/bash

# VM 인스턴스 배포용 프론트엔드 설정 스크립트
# 사용법: sudo ./setup.sh [백엔드_API_URL]

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 백엔드 API URL 설정 (기본값: /api)
BACKEND_API_URL="${1:-/api}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}프론트엔드 VM 배포 스크립트${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. Node.js 설치 확인
echo -e "${YELLOW}[1/7] Node.js 설치 확인 중...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js가 설치되어 있지 않습니다.${NC}"
    echo "Node.js 18 이상을 설치합니다..."
    
    # Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    # CentOS/RHEL
    elif command -v yum &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo yum install -y nodejs
    else
        echo -e "${RED}지원하지 않는 패키지 관리자입니다. Node.js를 수동으로 설치해주세요.${NC}"
        exit 1
    fi
fi

NODE_VERSION=$(node -v)
echo -e "${GREEN}✅ Node.js 설치됨: $NODE_VERSION${NC}"

# 2. nginx 설치 확인
echo -e "${YELLOW}[2/7] nginx 설치 확인 중...${NC}"
if ! command -v nginx &> /dev/null; then
    echo "nginx를 설치합니다..."
    
    # Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y nginx
    # CentOS/RHEL
    elif command -v yum &> /dev/null; then
        sudo yum install -y nginx
    else
        echo -e "${RED}지원하지 않는 패키지 관리자입니다. nginx를 수동으로 설치해주세요.${NC}"
        exit 1
    fi
fi

NGINX_VERSION=$(nginx -v 2>&1 | awk -F/ '{print $2}')
echo -e "${GREEN}✅ nginx 설치됨: $NGINX_VERSION${NC}"

# 3. 작업 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}[3/7] 작업 디렉토리: $SCRIPT_DIR${NC}"

# 4. 의존성 설치
echo -e "${YELLOW}[4/7] npm 의존성 설치 중...${NC}"
if [ ! -d "node_modules" ]; then
    npm ci
    echo -e "${GREEN}✅ 의존성 설치 완료${NC}"
else
    echo -e "${GREEN}✅ 의존성 이미 설치됨 (node_modules 존재)${NC}"
fi

# 5. 환경 변수 설정 및 빌드
echo -e "${YELLOW}[5/7] 프론트엔드 빌드 중...${NC}"
echo "백엔드 API URL: $BACKEND_API_URL"

# 빌드 시점에 API URL 설정
export VITE_API_BASE_URL="$BACKEND_API_URL"
npm run build

if [ ! -d "dist" ]; then
    echo -e "${RED}❌ 빌드 실패: dist 디렉토리가 생성되지 않았습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 빌드 완료${NC}"

# 6. nginx 설정 파일 준비
echo -e "${YELLOW}[6/7] nginx 설정 파일 준비 중...${NC}"

# 백엔드 URL 추출 (nginx.conf에서 사용)
if [[ "$BACKEND_API_URL" == http* ]]; then
    # 전체 URL인 경우 (예: http://backend:8000)
    BACKEND_HOST=$(echo "$BACKEND_API_URL" | sed -E 's|https?://([^/]+).*|\1|')
    BACKEND_PORT=$(echo "$BACKEND_HOST" | grep -oP ':\K\d+' || echo "8000")
    BACKEND_HOST=$(echo "$BACKEND_HOST" | sed 's/:.*//')
    BACKEND_URL="http://${BACKEND_HOST}:${BACKEND_PORT}"
else
    # 경로만 있는 경우 (예: /api) - 같은 서버의 백엔드로 프록시
    BACKEND_URL="http://localhost:8000"
fi

echo "백엔드 프록시 URL: $BACKEND_URL"

# nginx.conf 수정 (백엔드 URL 업데이트)
NGINX_CONF="/etc/nginx/sites-available/photo-album"
NGINX_CONF_ENABLED="/etc/nginx/sites-enabled/photo-album"

# nginx.conf를 sites-available에 복사
sudo cp nginx.conf "$NGINX_CONF"

# 백엔드 URL이 localhost가 아닌 경우 nginx.conf 수정
if [[ "$BACKEND_URL" != "http://localhost:8000" ]]; then
    sudo sed -i "s|proxy_pass http://backend:8000/;|proxy_pass $BACKEND_URL/;|g" "$NGINX_CONF"
fi

# sites-enabled에 심볼릭 링크 생성
if [ ! -L "$NGINX_CONF_ENABLED" ]; then
    sudo ln -s "$NGINX_CONF" "$NGINX_CONF_ENABLED"
fi

# 기본 nginx 설정 비활성화 (있는 경우)
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi

echo -e "${GREEN}✅ nginx 설정 파일 준비 완료${NC}"

# 7. 빌드된 파일 배포 및 nginx 재시작
echo -e "${YELLOW}[7/7] 파일 배포 및 nginx 재시작 중...${NC}"

# 웹 루트 디렉토리 생성
WEB_ROOT="/var/www/photo-album"
sudo mkdir -p "$WEB_ROOT"

# 빌드된 파일 복사
sudo cp -r dist/* "$WEB_ROOT/"

# 권한 설정
sudo chown -R www-data:www-data "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"

# nginx 설정 테스트
echo "nginx 설정 테스트 중..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx 설정 검증 성공${NC}"
    
    # nginx 재시작
    if sudo systemctl is-active --quiet nginx; then
        echo "nginx 재시작 중..."
        sudo systemctl reload nginx
    else
        echo "nginx 시작 중..."
        sudo systemctl start nginx
    fi
    
    # nginx 자동 시작 설정
    sudo systemctl enable nginx
    
    echo -e "${GREEN}✅ nginx 재시작 완료${NC}"
else
    echo -e "${RED}❌ nginx 설정 검증 실패${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}배포 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "서비스 정보:"
echo "  - 웹 루트: $WEB_ROOT"
echo "  - nginx 설정: $NGINX_CONF"
echo "  - 백엔드 API URL: $BACKEND_API_URL"
echo ""
echo "서비스 상태 확인:"
echo "  sudo systemctl status nginx"
echo ""
echo "로그 확인:"
echo "  sudo tail -f /var/log/nginx/error.log"
echo "  sudo tail -f /var/log/nginx/access.log"
echo ""
echo "브라우저에서 접속:"
echo "  http://$(hostname -I | awk '{print $1}')"
echo "  또는"
echo "  http://localhost"
echo ""
