#!/bin/bash
#
# 우분투 인스턴스 이미지 빌드 스크립트
#
# 사용법: sudo ./scripts/setup.sh (권장)
#         또는 환경 변수 설정 후 sudo -E ./scripts/build-instance-image.sh
#
# 수행 내용:
#   1. React 빌드 환경 (Node.js 20, npm)
#   2. React 앱 빌드 (dist 생성)
#   3. nginx 설치, 설정, 시작
#   4. Promtail 설치, 설정, 시작
#   5. Telegraf 설치, 설정, 시작
#
# 필요 환경 변수 (setup.sh에서 설정):
#   BACKEND_HOST, LOKI_URL, LOKI_LOGS_APP, LOKI_LOGS_ENV
#   INFLUX_URL, INFLUX_TOKEN, INFLUX_ORG, INFLUX_BUCKET, INFLUX_APP, INFLUX_ENV

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
echo "환경 변수 확인:"
echo "  BACKEND_HOST=${BACKEND_HOST:-172.16.2.46 (기본값)}"
echo "  LOKI_URL=${LOKI_URL:-(기본값 사용)}"
echo "  LOKI_LOGS_APP=${LOKI_LOGS_APP:-photo-frontend (기본값)}"
echo "  LOKI_LOGS_ENV=${LOKI_LOGS_ENV:-production (기본값)}"
echo "  INFLUX_URL=${INFLUX_URL:-(기본값 사용)}"
echo "  INFLUX_ORG=${INFLUX_ORG:-nhn-cloud (기본값)}"
echo "  INFLUX_BUCKET=${INFLUX_BUCKET:-monitoring (기본값)}"
echo ""

# ============================================================
# 1. 패키지 설치 (한 번에 모두 설치)
# ============================================================
echo "[1/5] 패키지 설치"

export DEBIAN_FRONTEND=noninteractive

# Node.js 저장소 추가 (필요한 경우)
if ! command -v node &> /dev/null; then
    echo "  Node.js 저장소 추가 중..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
fi

# InfluxData 저장소 추가 (필요한 경우)
if [ ! -f /etc/apt/sources.list.d/influxdata.list ]; then
    echo "  InfluxData 저장소 추가 중..."
    curl -sSL https://repos.influxdata.com/influxdata-archive.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/influxdata-archive.gpg 2>/dev/null
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main" > /etc/apt/sources.list.d/influxdata.list
fi

# apt-get update 한 번만 실행
echo "  패키지 목록 업데이트 중..."
apt-get update -qq

# 모든 패키지 한 번에 설치
echo "  패키지 설치 중..."
apt-get install -y -qq \
    curl ca-certificates gnupg unzip gettext-base \
    nginx nodejs telegraf

echo "  Node: $(node -v)  npm: $(npm -v)"
echo ""

# ============================================================
# 2. React 앱 빌드
# ============================================================
echo "[2/5] React 앱 빌드"

cd "$REPO_ROOT"

if [ -f "package.json" ]; then
    echo "  의존성 설치 중..."
    npm ci --silent --prefer-offline
    
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
# 3. nginx 설정 및 앱 배포
# ============================================================
echo "[3/5] nginx 설정 및 앱 배포"

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
    # 환경 변수로 백엔드 주소 설정 (기본값 사용)
    export BACKEND_HOST="${BACKEND_HOST:-172.16.2.46}"
    echo "  백엔드 주소: $BACKEND_HOST"
    
    # envsubst로 환경 변수 치환
    envsubst '${BACKEND_HOST}' < "$REPO_ROOT/nginx.conf" > "$NGINX_CONF"
    
    if [ ! -L "$NGINX_ENABLED" ]; then
        ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
    fi
    rm -f /etc/nginx/sites-enabled/default
    
    # nginx 설정 검증 및 시작
    if nginx -t; then
        systemctl enable nginx
        systemctl restart nginx
        echo "  nginx 설정 완료 및 시작: $NGINX_CONF"
    else
        echo "  오류: nginx 설정 검증 실패"
        exit 1
    fi
else
    echo "  경고: nginx.conf 없음, 기본 설정 유지"
fi

echo ""

# ============================================================
# 4. Promtail 설치 및 설정
# ============================================================
echo "[4/5] Promtail 설치 및 설정"

PROMTAIL_DIR="/opt/promtail"
PROMTAIL_CONFIG="$PROMTAIL_DIR/promtail-config.yaml"
PROMTAIL_VERSION="${PROMTAIL_VERSION:-2.9.5}"

mkdir -p "$PROMTAIL_DIR"

# Promtail 다운로드 (이미 있으면 스킵)
if [ ! -x "$PROMTAIL_DIR/promtail" ]; then
    echo "  Promtail ${PROMTAIL_VERSION} 다운로드 중..."
    cd /tmp
    curl -sSL -o promtail.zip "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
    unzip -o -q promtail.zip
    mv promtail-linux-amd64 "$PROMTAIL_DIR/promtail"
    chmod +x "$PROMTAIL_DIR/promtail"
    rm -f promtail.zip
    cd - > /dev/null
    echo "  Promtail 다운로드 완료"
fi

# 템플릿 파일: conf/promtail-config.yaml → /opt/promtail/promtail-config.yaml.template
PROMTAIL_TEMPLATE="$PROMTAIL_DIR/promtail-config.yaml.template"
if [ -f "$CONF_DIR/promtail-config.yaml" ]; then
    cp "$CONF_DIR/promtail-config.yaml" "$PROMTAIL_TEMPLATE"
    chmod 644 "$PROMTAIL_TEMPLATE"
    echo "  템플릿: $PROMTAIL_TEMPLATE"
    
    # 환경 변수 파일 생성 (/etc/default/promtail)
    cat > /etc/default/promtail << 'ENVEOF'
# Promtail 환경 변수 설정
# systemctl restart promtail 하면 이 파일의 값이 적용됩니다.
# INSTANCE_IP는 서비스 시작 시 자동으로 감지됩니다.

# Loki 설정
LOKI_URL=http://172.16.4.20:3100/loki/api/v1/push
LOKI_LOGS_APP=photo-frontend
LOKI_LOGS_ENV=production
ENVEOF

    # 빌드 시 전달된 환경 변수가 있으면 덮어쓰기
    if [ -n "$LOKI_URL" ]; then
        sed -i "s|^LOKI_URL=.*|LOKI_URL=$LOKI_URL|" /etc/default/promtail
    fi
    if [ -n "$LOKI_LOGS_APP" ]; then
        sed -i "s|^LOKI_LOGS_APP=.*|LOKI_LOGS_APP=$LOKI_LOGS_APP|" /etc/default/promtail
    fi
    if [ -n "$LOKI_LOGS_ENV" ]; then
        sed -i "s|^LOKI_LOGS_ENV=.*|LOKI_LOGS_ENV=$LOKI_LOGS_ENV|" /etc/default/promtail
    fi
    
    echo "  환경변수: /etc/default/promtail"
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

# systemd 서비스 (환경 변수를 런타임에 적용)
cat > /etc/systemd/system/promtail.service << 'EOF'
[Unit]
Description=Promtail - log shipper for Loki
After=network.target nginx.service

[Service]
Type=simple
User=root
EnvironmentFile=/etc/default/promtail

# 시작 전에 환경 변수로 설정 파일 생성 (INSTANCE_IP는 동적으로 감지)
ExecStartPre=/bin/bash -c 'set -a && source /etc/default/promtail && set +a && export INSTANCE_IP=$(hostname -I | cut -d" " -f1) && envsubst < /opt/promtail/promtail-config.yaml.template > /opt/promtail/promtail-config.yaml'

ExecStart=/opt/promtail/promtail -config.file=/opt/promtail/promtail-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promtail
systemctl start promtail
echo "  Promtail 서비스 시작 완료"
echo ""

# ============================================================
# 5. Telegraf 설정
# ============================================================
echo "[5/5] Telegraf 설정"

TELEGRAF_DIR="/opt/telegraf"
TELEGRAF_CONFIG="$TELEGRAF_DIR/telegraf.conf"

mkdir -p "$TELEGRAF_DIR"

# 템플릿 파일: conf/telegraf.conf → /opt/telegraf/telegraf.conf.template
TELEGRAF_TEMPLATE="$TELEGRAF_DIR/telegraf.conf.template"
if [ -f "$CONF_DIR/telegraf.conf" ]; then
    cp "$CONF_DIR/telegraf.conf" "$TELEGRAF_TEMPLATE"
    chmod 644 "$TELEGRAF_TEMPLATE"
    echo "  템플릿: $TELEGRAF_TEMPLATE"
    
    # 환경 변수 파일 생성 (/etc/default/telegraf)
    cat > /etc/default/telegraf << 'ENVEOF'
# Telegraf 환경 변수 설정
# systemctl restart telegraf 하면 이 파일의 값이 적용됩니다.
# INSTANCE_IP는 서비스 시작 시 자동으로 감지됩니다.

# InfluxDB 설정
INFLUX_URL=http://172.16.4.20:8086
INFLUX_TOKEN=your-token-here
INFLUX_ORG=nhn-cloud
INFLUX_BUCKET=monitoring
INFLUX_APP=photo-frontend
INFLUX_ENV=production
ENVEOF

    # 빌드 시 전달된 환경 변수가 있으면 덮어쓰기
    if [ -n "$INFLUX_URL" ]; then
        sed -i "s|^INFLUX_URL=.*|INFLUX_URL=$INFLUX_URL|" /etc/default/telegraf
    fi
    if [ -n "$INFLUX_TOKEN" ]; then
        sed -i "s|^INFLUX_TOKEN=.*|INFLUX_TOKEN=$INFLUX_TOKEN|" /etc/default/telegraf
    fi
    if [ -n "$INFLUX_ORG" ]; then
        sed -i "s|^INFLUX_ORG=.*|INFLUX_ORG=$INFLUX_ORG|" /etc/default/telegraf
    fi
    if [ -n "$INFLUX_BUCKET" ]; then
        sed -i "s|^INFLUX_BUCKET=.*|INFLUX_BUCKET=$INFLUX_BUCKET|" /etc/default/telegraf
    fi
    if [ -n "$INFLUX_APP" ]; then
        sed -i "s|^INFLUX_APP=.*|INFLUX_APP=$INFLUX_APP|" /etc/default/telegraf
    fi
    if [ -n "$INFLUX_ENV" ]; then
        sed -i "s|^INFLUX_ENV=.*|INFLUX_ENV=$INFLUX_ENV|" /etc/default/telegraf
    fi
    
    echo "  환경변수: /etc/default/telegraf"
else
    echo "  경고: conf/telegraf.conf 없음. 기본 설정을 생성합니다."
    telegraf --input-filter nginx --output-filter file config > "$TELEGRAF_TEMPLATE" 2>/dev/null || true
fi

# systemd override: 환경 변수를 런타임에 적용
mkdir -p /etc/systemd/system/telegraf.service.d
cat > /etc/systemd/system/telegraf.service.d/override.conf << 'EOF'
[Service]
EnvironmentFile=/etc/default/telegraf

# 시작 전에 환경 변수로 설정 파일 생성 (INSTANCE_IP는 동적으로 감지)
ExecStartPre=/bin/bash -c 'set -a && source /etc/default/telegraf && set +a && export INSTANCE_IP=$(hostname -I | cut -d" " -f1) && envsubst < /opt/telegraf/telegraf.conf.template > /opt/telegraf/telegraf.conf'

ExecStart=
ExecStart=/usr/bin/telegraf -config /opt/telegraf/telegraf.conf
EOF

systemctl daemon-reload
systemctl enable telegraf
systemctl start telegraf
echo "  Telegraf 서비스 시작 완료"
echo ""

# ============================================================
# 서비스 상태 확인
# ============================================================
echo "=========================================="
echo "서비스 상태 확인"
echo "=========================================="
echo ""
echo "nginx:"
systemctl is-active nginx && echo "  상태: 실행 중" || echo "  상태: 중지됨"
echo ""
echo "promtail:"
systemctl is-active promtail && echo "  상태: 실행 중" || echo "  상태: 중지됨"
echo ""
echo "telegraf:"
systemctl is-active telegraf && echo "  상태: 실행 중" || echo "  상태: 중지됨"
echo ""

# ============================================================
# 정리 및 안내
# ============================================================
echo "=========================================="
echo "인스턴스 빌드 완료"
echo "=========================================="
echo ""
echo "설치 요약:"
echo "  - Node.js: $(node -v)"
echo "  - nginx: $(nginx -v 2>&1)"
echo "  - 앱 배포: $WEB_ROOT"
echo ""
echo "적용된 설정:"
echo "  - BACKEND_HOST: $BACKEND_HOST"
echo "  - LOKI_URL: $(grep '^LOKI_URL=' /etc/default/promtail | cut -d= -f2)"
echo "  - INFLUX_URL: $(grep '^INFLUX_URL=' /etc/default/telegraf | cut -d= -f2)"
echo "  - INSTANCE_IP: $(hostname -I | cut -d' ' -f1)"
echo ""
echo "설정 파일 위치:"
echo "  - nginx: /etc/nginx/sites-available/photo-album"
echo "  - Promtail: /etc/default/promtail (환경변수)"
echo "  - Telegraf: /etc/default/telegraf (환경변수)"
echo ""
echo "설정 변경 후 서비스 재시작:"
echo "  sudo systemctl restart nginx"
echo "  sudo systemctl restart promtail"
echo "  sudo systemctl restart telegraf"
echo ""
