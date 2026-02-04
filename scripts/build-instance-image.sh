#!/bin/bash
#
# 우분투 인스턴스 이미지 빌드 스크립트
# 사용법: 이 저장소를 인스턴스에 클론한 뒤, sudo ./scripts/build-instance-image.sh
#
# 수행 내용:
#   1. React 빌드 환경 (Node.js 20, npm)
#   2. React 앱 빌드 (dist 생성)
#   3. nginx 설치 및 빌드된 앱 배포
#   4. Promtail 설치 및 /opt/promtail/promtail-config.yaml 구성
#   5. Telegraf 설치 및 /opt/telegraf/telegraf.conf 구성
#
# 주의: nginx.conf의 백엔드 주소는 기본값(192.168.2.55)으로 설정됩니다.
#       환경에 맞게 /etc/nginx/sites-available/photo-album 을 수정하거나
#       deploy.sh를 사용하세요.

set -e

# 저장소 루트 (스크립트 위치 기준)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_ROOT/conf"

# root 확인
if [ "$(id -u)" -ne 0 ]; then
    echo "root 권한이 필요합니다. sudo ./scripts/build-instance-image.sh 로 실행하세요."
    exit 1
fi

echo "=========================================="
echo "우분투 인스턴스 이미지 빌드"
echo "=========================================="
echo "저장소 루트: $REPO_ROOT"
echo ""

# ============================================================
# 1. React 빌드 환경 (Node.js 20, npm)
# ============================================================
echo "[1/4] React 빌드 환경 설치"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg unzip

if ! command -v node &> /dev/null; then
    echo "Node.js 20 설치 중..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo "  Node: $(node -v)  npm: $(npm -v)"
echo ""

# ============================================================
# 2. React 앱 빌드 및 배포
# ============================================================
echo "[2/4] React 앱 빌드"

cd "$REPO_ROOT"

# 의존성 설치
if [ -f "package.json" ]; then
    echo "  의존성 설치 중..."
    npm ci --silent
    
    # 빌드 수행
    echo "  React 앱 빌드 중..."
    export VITE_API_BASE_URL="/api"
    npm run build
    
    if [ ! -d "dist" ]; then
        echo "  오류: dist 디렉토리가 생성되지 않았습니다."
        exit 1
    fi
    
    echo "  빌드 완료: $(du -sh dist | cut -f1)"
else
    echo "  경고: package.json을 찾을 수 없습니다. 빌드를 건너뜁니다."
fi

echo ""

# ============================================================
# 3. nginx 설치 및 앱 배포
# ============================================================
echo "[3/4] nginx 설치 및 앱 배포"

apt-get install -y -qq nginx

WEB_ROOT="/var/www/photo-album"
mkdir -p "$WEB_ROOT"

# 빌드된 파일 배포
if [ -d "$REPO_ROOT/dist" ]; then
    echo "  빌드된 파일을 $WEB_ROOT 에 배포 중..."
    cp -r "$REPO_ROOT/dist/"* "$WEB_ROOT/"
    echo "  배포 완료"
else
    echo "  경고: dist 디렉토리가 없습니다. placeholder 페이지를 생성합니다."
    echo "<!DOCTYPE html><html><body>Photo Album - deploy with deploy.sh</body></html>" > "$WEB_ROOT/index.html"
fi

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

# nginx 설정
NGINX_CONF="/etc/nginx/sites-available/photo-album"
NGINX_ENABLED="/etc/nginx/sites-enabled/photo-album"

if [ -f "$REPO_ROOT/nginx.conf" ]; then
    cp "$REPO_ROOT/nginx.conf" "$NGINX_CONF"
    
    # 백엔드 주소가 placeholder로 되어 있다면 기본값 설정
    # (나중에 deploy.sh나 수동으로 수정 필요)
    if grep -q "__BACKEND_UPSTREAM__" "$NGINX_CONF"; then
        echo "  경고: nginx.conf에 placeholder가 있습니다. 기본값(192.168.2.55)으로 설정합니다."
        sed -i "s|__BACKEND_UPSTREAM__|192.168.2.55|g" "$NGINX_CONF"
        sed -i "s|__BACKEND_HOST__|192.168.2.55|g" "$NGINX_CONF"
    fi
    
    if [ ! -L "$NGINX_ENABLED" ]; then
        ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
    fi
    rm -f /etc/nginx/sites-enabled/default
    
    # nginx 설정 검증
    if nginx -t 2>/dev/null; then
        systemctl enable nginx
        echo "  nginx 설정 완료: $NGINX_CONF"
    else
        echo "  경고: nginx 설정 검증 실패. 수동으로 확인하세요."
    fi
else
    echo "  경고: nginx.conf 없음, 기본 설정 유지"
fi

echo ""

# ============================================================
# 4. Promtail 설치 및 /opt/promtail 구성
# ============================================================
echo "[4/5] Promtail 설치 및 구성"

PROMTAIL_DIR="/opt/promtail"
PROMTAIL_CONFIG="$PROMTAIL_DIR/promtail-config.yaml"
PROMTAIL_VERSION="${PROMTAIL_VERSION:-2.9.5}"

mkdir -p "$PROMTAIL_DIR"

# 바이너리 다운로드 (이미 있으면 스킵)
if [ ! -x "$PROMTAIL_DIR/promtail" ]; then
    echo "  Promtail ${PROMTAIL_VERSION} 다운로드 중..."
    cd /tmp
    curl -sSL -o promtail.zip "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
    unzip -o -q promtail.zip
    mv promtail-linux-amd64 "$PROMTAIL_DIR/promtail"
    chmod +x "$PROMTAIL_DIR/promtail"
    rm -f promtail.zip
    cd - > /dev/null
fi

# 설정 파일: conf/promtail-config.yaml → /opt/promtail/promtail-config.yaml
if [ -f "$CONF_DIR/promtail-config.yaml" ]; then
    cp "$CONF_DIR/promtail-config.yaml" "$PROMTAIL_CONFIG"
    
    # hostname -I로 인스턴스 IP 가져와서 설정에 반영
    HOST_IP=$(hostname -I | awk '{print $1}')
    if [ -n "$HOST_IP" ]; then
        sed -i "s|__HOST_IP__|$HOST_IP|g" "$PROMTAIL_CONFIG"
        echo "  인스턴스 IP: $HOST_IP"
    else
        echo "  경고: 인스턴스 IP를 가져올 수 없습니다."
        sed -i "s|__HOST_IP__|unknown|g" "$PROMTAIL_CONFIG"
    fi
    
    chmod 644 "$PROMTAIL_CONFIG"
    echo "  설정: $PROMTAIL_CONFIG"
else
    echo "  경고: conf/promtail-config.yaml 없음. 기본 설정을 생성합니다."
    cat > "$PROMTAIL_CONFIG" << 'PROMTAIL_EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0
positions:
  filename: /opt/promtail/positions.yaml
clients:
  - url: http://${LOKI_URL}:3100/loki/api/v1/push
scrape_configs:
  - job_name: nginx-access
    static_configs:
      - targets: [localhost]
        labels:
          job: nginx
          __path__: /var/log/nginx/access.log
  - job_name: nginx-error
    static_configs:
      - targets: [localhost]
        labels:
          job: nginx-error
          __path__: /var/log/nginx/error.log
PROMTAIL_EOF
fi

# positions 파일 터치
touch "$PROMTAIL_DIR/positions.yaml"
chown -R root:root "$PROMTAIL_DIR"

# systemd 서비스
cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail - log shipper for Loki
After=network.target nginx.service

[Service]
Type=simple
User=root
ExecStart=$PROMTAIL_DIR/promtail -config.file=$PROMTAIL_CONFIG
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promtail
echo "  Promtail 서비스 등록 완료 (시작은 인스턴스 부팅 시 또는 수동 start)"
echo ""

# ============================================================
# 5. Telegraf 설치 및 /opt/telegraf 구성
# ============================================================
echo "[5/5] Telegraf 설치 및 구성"

TELEGRAF_DIR="/opt/telegraf"
TELEGRAF_CONFIG="$TELEGRAF_DIR/telegraf.conf"

mkdir -p "$TELEGRAF_DIR"

# InfluxData APT 저장소 추가
if [ ! -f /etc/apt/sources.list.d/influxdata.list ]; then
    curl -sSL https://repos.influxdata.com/influxdata-archive.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/influxdata-archive.gpg
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main" > /etc/apt/sources.list.d/influxdata.list
    apt-get update -qq
fi

if ! command -v telegraf &> /dev/null; then
    apt-get install -y -qq telegraf
fi

# 설정 파일: conf/telegraf.conf → /opt/telegraf/telegraf.conf
if [ -f "$CONF_DIR/telegraf.conf" ]; then
    cp "$CONF_DIR/telegraf.conf" "$TELEGRAF_CONFIG"
    chmod 644 "$TELEGRAF_CONFIG"
    echo "  설정: $TELEGRAF_CONFIG"
else
    echo "  경고: conf/telegraf.conf 없음. 기본 설정을 생성합니다."
    telegraf --input-filter nginx --output-filter file config > "$TELEGRAF_CONFIG" 2>/dev/null || true
fi

# systemd override: 기본 설정 대신 /opt/telegraf/telegraf.conf 사용
mkdir -p /etc/systemd/system/telegraf.service.d
cat > /etc/systemd/system/telegraf.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/telegraf -config $TELEGRAF_CONFIG
EOF

systemctl daemon-reload
systemctl enable telegraf
echo "  Telegraf 서비스 등록 완료 (시작은 인스턴스 부팅 시 또는 수동 start)"
echo ""

# ============================================================
# 정리 및 안내
# ============================================================
echo "=========================================="
echo "인스턴스 이미지 빌드 완료"
echo "=========================================="
echo ""
echo "설치 요약:"
echo "  - Node.js: $(node -v)"
echo "  - nginx: $(nginx -v 2>&1)"
echo "  - 앱 배포: $WEB_ROOT"
echo "  - Promtail: $PROMTAIL_DIR (config: $PROMTAIL_CONFIG)"
echo "  - Telegraf: $TELEGRAF_DIR (config: $TELEGRAF_CONFIG)"
echo ""
echo "다음 단계:"
echo "  1. 이 인스턴스로 AMI/이미지를 생성하세요."
echo "  2. 새 인스턴스 기동 후:"
echo "     - nginx가 자동으로 시작됩니다 (앱이 이미 배포되어 있음)"
echo "     - 백엔드 주소 변경 시: /etc/nginx/sites-available/photo-album 수정 후 nginx reload"
echo "     - 또는 deploy.sh를 사용하여 재배포"
echo "  3. 필요 시 Promtail LOKI_URL, Telegraf 출력(예: InfluxDB)을 수정하세요."
echo ""
