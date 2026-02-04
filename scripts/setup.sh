#!/bin/bash
#
# 인스턴스 설정 및 빌드 실행 스크립트
#
# 사용법: sudo ./scripts/setup.sh
#
# 이 파일에서 환경 변수를 설정한 후, build-instance-image.sh를 실행합니다.
# 환경에 맞게 아래 값들을 수정하세요.

set -e

# ============================================================
# 환경 변수 설정 (필요에 따라 수정)
# ============================================================

# nginx 백엔드 주소
export BACKEND_HOST="172.16.2.46"

# Promtail (Loki 로깅)
export LOKI_URL="http://172.16.4.20:3100/loki/api/v1/push"
export LOKI_LOGS_APP="photo-frontend"
export LOKI_LOGS_ENV="production"

# Telegraf (InfluxDB 메트릭)
export INFLUX_URL="http://172.16.4.20:8086"
export INFLUX_TOKEN="your-token-here"
export INFLUX_ORG="nhn-cloud"
export INFLUX_BUCKET="monitoring"
export INFLUX_APP="photo-frontend"
export INFLUX_ENV="production"

# ============================================================
# 빌드 스크립트 실행
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "환경 변수 설정"
echo "=========================================="
echo "BACKEND_HOST: $BACKEND_HOST"
echo "LOKI_URL: $LOKI_URL"
echo "LOKI_LOGS_APP: $LOKI_LOGS_APP"
echo "LOKI_LOGS_ENV: $LOKI_LOGS_ENV"
echo "INFLUX_URL: $INFLUX_URL"
echo "INFLUX_ORG: $INFLUX_ORG"
echo "INFLUX_BUCKET: $INFLUX_BUCKET"
echo "=========================================="
echo ""

# 빌드 스크립트 실행
exec "$SCRIPT_DIR/build-instance-image.sh"
