#!/bin/bash
#
# 우분투 인스턴스 이미지 빌드 스크립트
# 사용법: 이 저장소를 인스턴스에 클론한 뒤, sudo ./scripts/build-instance-image.sh
#
# 수행 내용:
#   1. React 빌드 환경 (Node.js 18, npm)
#   2. nginx 설치 및 배포용 설정
#   3. Promtail 설치 및 /opt/promtail/promtail-config.yaml 구성
#   4. Telegraf 설치 및 /opt/telegraf/telegraf.conf 구성
#
# 배포 시: deploy.sh 로 앱을 배포하고, 백엔드 주소를 설정하세요.

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
# 1. React 빌드 환경 (Node.js 18, npm)
# ============================================================
echo "[1/4] React 빌드 환경 설치"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg unzip

if ! command -v node &> /dev/null; then
    echo "Node.js 18 설치 중..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

echo "  Node: $(node -v)  npm: $(npm -v)"
echo ""

# ============================================================
# 2. nginx 설치 및 배포용 설정
# ============================================================
echo "[2/4] nginx 설치 및 설정"

apt-get install -y -qq nginx

WEB_ROOT="/var/www/photo-album"
mkdir -p "$WEB_ROOT"
# placeholder 페이지 (실제 앱은 deploy.sh로 배포)
echo "<!DOCTYPE html><html><body>Photo Album - deploy with deploy.sh</body></html>" > "$WEB_ROOT/index.html"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

# nginx 설정 (placeholder 유지 - deploy.sh에서 백엔드 주소 치환)
NGINX_CONF="/etc/nginx/sites-available/photo-album"
NGINX_ENABLED="/etc/nginx/sites-enabled/photo-album"

if [ -f "$REPO_ROOT/nginx.conf" ]; then
    cp "$REPO_ROOT/nginx.conf" "$NGINX_CONF"
    if [ ! -L "$NGINX_ENABLED" ]; then
        ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
    fi
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl enable nginx
    echo "  nginx 설정: $NGINX_CONF (백엔드 주소는 deploy.sh에서 치환)"
else
    echo "  경고: nginx.conf 없음, 기본 설정 유지"
fi

echo ""

# ============================================================
# 3. Promtail 설치 및 /opt/promtail 구성
# ============================================================
echo "[3/4] Promtail 설치 및 구성"

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
  - url: http://localhost:3100/loki/api/v1/push
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
# 4. Telegraf 설치 및 /opt/telegraf 구성
# ============================================================
echo "[4/4] Telegraf 설치 및 구성"

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
echo "  - Node.js: $(node -v) (React 빌드용)"
echo "  - nginx: $(nginx -v 2>&1)"
echo "  - Promtail: $PROMTAIL_DIR (config: $PROMTAIL_CONFIG)"
echo "  - Telegraf: $TELEGRAF_DIR (config: $TELEGRAF_CONFIG)"
echo ""
echo "다음 단계:"
echo "  1. 이 인스턴스로 AMI/이미지를 생성하세요."
echo "  2. 새 인스턴스 기동 후 압축 파일을 /opt/photo-frontend/에 업로드하고 deploy.sh 실행."
echo "  3. deploy.sh 상단에서 BACKEND_UPSTREAM, BACKEND_HOST 를 해당 환경에 맞게 수정하세요."
echo "  4. 필요 시 Promtail LOKI_URL, Telegraf 출력(예: InfluxDB)을 수정하세요."
echo ""
