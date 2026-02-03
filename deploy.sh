#!/bin/bash

# 웹서버 배포 스크립트
# 사용법: sudo ./deploy.sh
#
# 배포 경로: /opt/photo-frontend/
# - 압축 파일을 /opt/photo-frontend/에 업로드
# - 압축 해제 후 이 스크립트 실행
#
# 리전/환경별 백엔드 주소는 아래 변수를 수정한 뒤 배포하세요.

set -e

# ============================================================
# 백엔드 주소 (nginx proxy_pass / Host 헤더) - 여기를 수정하세요
# ============================================================
BACKEND_UPSTREAM="192.168.2.48:80"
BACKEND_HOST="192.168.2.48"
# ============================================================

# 애플리케이션 디렉토리 (압축 해제된 위치)
APP_DIR="/opt/photo-frontend"

echo "=========================================="
echo "웹서버 배포 시작"
echo "=========================================="
echo ""

# 애플리케이션 디렉토리 확인
if [ ! -d "$APP_DIR" ]; then
    echo "오류: 애플리케이션 디렉토리가 없습니다: $APP_DIR"
    echo "압축 파일을 $APP_DIR에 업로드하고 압축을 해제하세요."
    exit 1
fi

# 작업 디렉토리로 이동
cd "$APP_DIR"
echo "작업 디렉토리: $APP_DIR"

# 압축 파일이 있으면 자동으로 해제
ARCHIVE_FILE=""
if ls photo-frontend-*.tar.gz 1> /dev/null 2>&1; then
    ARCHIVE_FILE=$(ls photo-frontend-*.tar.gz | head -1)
elif ls frontend.zip 1> /dev/null 2>&1; then
    ARCHIVE_FILE="frontend.zip"
elif ls *.zip 1> /dev/null 2>&1; then
    ARCHIVE_FILE=$(ls *.zip | head -1)
elif ls *.tar.gz 1> /dev/null 2>&1; then
    ARCHIVE_FILE=$(ls *.tar.gz | head -1)
fi

if [ -n "$ARCHIVE_FILE" ]; then
    echo ""
    echo "[0/5] 압축 파일 해제"
    echo "압축 파일 발견: $ARCHIVE_FILE"
    echo "압축 해제 중..."

    if [[ "$ARCHIVE_FILE" == *.zip ]]; then
        # zip 파일 해제
        if ! command -v unzip &> /dev/null; then
            echo "unzip 설치 중..."
            if command -v apt-get &> /dev/null; then
                sudo apt-get update
                sudo apt-get install -y unzip
            elif command -v yum &> /dev/null; then
                sudo yum install -y unzip
            fi
        fi
        sudo unzip -q -o "$ARCHIVE_FILE"
    else
        # tar.gz 파일 해제
        sudo tar -xzf "$ARCHIVE_FILE"
    fi
    echo "압축 해제 완료"

    # 압축 해제 후 디렉토리 구조 확인
    echo ""
    echo "압축 해제 후 디렉토리 구조:"
    ls -la | head -15
    echo ""

    # frontend 디렉토리가 있으면 내용을 상위 디렉토리로 이동
    if [ -d "frontend" ] && [ ! -f "frontend/frontend.zip" ]; then
        echo "frontend 디렉토리 내용을 상위 디렉토리로 이동 중..."
        sudo mv frontend/* frontend/.[!.]* . 2>/dev/null || sudo cp -r frontend/* . 2>/dev/null
        sudo rmdir frontend 2>/dev/null || true
        echo "이동 완료"
        echo ""
        echo "이동 후 디렉토리 구조:"
        ls -la | head -15
        echo ""
    fi

    # __MACOSX 디렉토리 제거 (macOS에서 생성된 불필요한 파일)
    if [ -d "__MACOSX" ]; then
        echo "__MACOSX 디렉토리 제거 중..."
        sudo rm -rf __MACOSX
    fi
fi

# 현재 디렉토리 구조 확인 (디버깅용)
if [ -z "$ARCHIVE_FILE" ]; then
    echo "현재 디렉토리 구조:"
    ls -la | head -10
    echo ""
fi

echo "[1/5] nginx 설치 확인"
if ! command -v nginx &> /dev/null; then
    echo "nginx 설치 중..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y nginx
    elif command -v yum &> /dev/null; then
        sudo yum install -y nginx
    else
        echo "오류: 지원하지 않는 패키지 관리자입니다."
        exit 1
    fi
fi
echo "nginx 설치 완료"
echo ""

# dist 디렉토리 확인 및 빌드
echo "[2/5] 빌드 파일 확인 및 빌드"
DIST_DIR=""

# 현재 디렉토리에 dist가 있는지 확인
if [ -d "dist" ]; then
    DIST_DIR="dist"
# 하위 디렉토리에 dist가 있는지 확인 (압축 해제 시 photo-frontend/dist 구조일 수 있음)
elif [ -d "photo-frontend/dist" ]; then
    DIST_DIR="photo-frontend/dist"
    cd photo-frontend
    APP_DIR="$APP_DIR/photo-frontend"
# 다른 하위 디렉토리 확인
else
    FOUND_DIST=$(find . -maxdepth 2 -type d -name "dist" 2>/dev/null | head -1)
    if [ -n "$FOUND_DIST" ]; then
        DIST_DIR="$FOUND_DIST"
        DIST_PARENT=$(dirname "$FOUND_DIST")
        if [ "$DIST_PARENT" != "." ]; then
            cd "$DIST_PARENT"
            APP_DIR="$APP_DIR/$DIST_PARENT"
        fi
    fi
fi

# dist 디렉토리가 없으면 빌드 수행
if [ -z "$DIST_DIR" ] || [ ! -d "dist" ]; then
    echo "dist 디렉토리가 없습니다. 빌드를 수행합니다..."

    # package.json 확인
    if [ ! -f "package.json" ]; then
        echo "오류: package.json을 찾을 수 없습니다."
        echo "현재 위치: $(pwd)"
        echo "디렉토리 내용:"
        ls -la
        exit 1
    fi

    # Node.js 설치 확인
    if ! command -v node &> /dev/null; then
        echo "Node.js 설치 중..."
        if command -v apt-get &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v yum &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo yum install -y nodejs
        else
            echo "오류: Node.js를 설치할 수 없습니다."
            exit 1
        fi
    fi

    echo "Node.js 버전: $(node -v)"
    echo "npm 버전: $(npm -v)"

    # 의존성 설치
    echo "의존성 설치 중..."
    npm ci

    # 빌드 수행
    echo "프론트엔드 빌드 중..."
    export VITE_API_BASE_URL="/api"
    npm run build

    if [ ! -d "dist" ]; then
        echo "오류: 빌드 후에도 dist 디렉토리가 생성되지 않았습니다."
        exit 1
    fi

    echo "빌드 완료"
    DIST_DIR="dist"
fi

echo "빌드 파일 확인 완료: $(pwd)/dist"
echo ""

# nginx 설정
echo "[3/5] nginx 설정"
NGINX_CONF="/etc/nginx/sites-available/photo-album"
NGINX_CONF_ENABLED="/etc/nginx/sites-enabled/photo-album"

# nginx.conf 파일 찾기
NGINX_CONF_SOURCE=""
if [ -f "nginx.conf" ]; then
    NGINX_CONF_SOURCE="nginx.conf"
elif [ -f "../nginx.conf" ]; then
    NGINX_CONF_SOURCE="../nginx.conf"
else
    NGINX_CONF_SOURCE=$(find .. -maxdepth 1 -name "nginx.conf" 2>/dev/null | head -1)
    if [ -z "$NGINX_CONF_SOURCE" ]; then
        echo "오류: nginx.conf 파일을 찾을 수 없습니다."
        exit 1
    fi
fi

echo "nginx.conf 위치: $NGINX_CONF_SOURCE"
echo "백엔드 upstream: $BACKEND_UPSTREAM, Host: $BACKEND_HOST"

# nginx.conf 복사
sudo cp "$NGINX_CONF_SOURCE" "$NGINX_CONF"

# nginx.conf 내 placeholder 치환 (deploy.sh 상단에 기입한 백엔드 주소 적용)
sudo sed -i "s|__BACKEND_UPSTREAM__|$BACKEND_UPSTREAM|g" "$NGINX_CONF"
sudo sed -i "s|__BACKEND_HOST__|$BACKEND_HOST|g" "$NGINX_CONF"

# sites-enabled에 심볼릭 링크 생성
if [ ! -L "$NGINX_CONF_ENABLED" ]; then
    sudo ln -s "$NGINX_CONF" "$NGINX_CONF_ENABLED"
fi

# 기본 nginx 설정 비활성화
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi

echo "nginx 설정 완료"
echo ""

# 파일 배포
echo "[4/5] 파일 배포 및 nginx 재시작"
WEB_ROOT="/var/www/photo-album"
sudo mkdir -p "$WEB_ROOT"
sudo cp -r dist/* "$WEB_ROOT/"
sudo chown -R www-data:www-data "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"

# nginx 설정 테스트 및 재시작
if sudo nginx -t; then
    if sudo systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx
    else
        sudo systemctl start nginx
    fi
    sudo systemctl enable nginx
    echo "nginx 재시작 완료"
else
    echo "오류: nginx 설정 검증 실패"
    exit 1
fi

echo "[5/5] 배포 완료"

echo ""
echo "=========================================="
echo "배포 완료"
echo "=========================================="
echo ""
echo "서비스 정보:"
echo "  - 애플리케이션 디렉토리: $APP_DIR"
echo "  - 웹 루트: $WEB_ROOT"
echo "  - nginx 설정: $NGINX_CONF"
echo "  - 백엔드 upstream: $BACKEND_UPSTREAM"
echo ""
echo "서비스 상태: sudo systemctl status nginx"
echo ""
echo "다음 배포 시:"
echo "  1. 백엔드 주소 변경 시 deploy.sh 상단 BACKEND_UPSTREAM/BACKEND_HOST 수정"
echo "  2. 압축 파일을 $APP_DIR에 업로드"
echo "  3. cd $APP_DIR && sudo tar -xzf photo-frontend-*.tar.gz"
echo "  4. sudo ./deploy.sh"
echo ""
