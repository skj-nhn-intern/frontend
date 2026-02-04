#!/bin/bash
#
# 배포 앱에서 이 코드만 실행. 스크립트로 실행하지 않음 (sudo ./start-with-env.sh 안 함).
# 환경 변수는 이미 export 되어 있다고 가정. 필요한 명령만 sudo 로 실행.
#

set -e

# export 된 환경 변수를 /etc/default/* 에 기록
sudo tee /etc/default/photo-album << EOF
BACKEND_HOST=${BACKEND_HOST:-192.168.2.55}
EOF

sudo tee /etc/default/promtail << EOF
LOKI_URL=${LOKI_URL:-http://192.168.4.73:3100/loki/api/v1/push}
LOKI_LOGS_APP=${LOKI_LOGS_APP:-photo-frontend}
LOKI_LOGS_ENV=${LOKI_LOGS_ENV:-production}
EOF

sudo tee /etc/default/telegraf << EOF
INFLUX_URL=${INFLUX_URL:-http://192.168.4.73:8086}
INFLUX_TOKEN=${INFLUX_TOKEN:-your-token-here}
INFLUX_ORG=${INFLUX_ORG:-nhn-cloud}
INFLUX_BUCKET=${INFLUX_BUCKET:-monitoring}
INFLUX_APP=${INFLUX_APP:-photo-frontend}
INFLUX_ENV=${INFLUX_ENV:-production}
EOF

# nginx 설정 파일 생성
envsubst '${BACKEND_HOST}' < /opt/nginx/photo-album.conf.template | sudo tee /etc/nginx/sites-available/photo-album > /dev/null

# photo-album-nginx-config.service 가 깨진 ExecStart 로 실패하면 nginx 도 안 뜸.
# 해당 서비스가 쓰는 스크립트를 만들어 두고, unit 의 ExecStart 를 이 스크립트로 바꿈.
sudo tee /opt/nginx/generate-photo-album-config.sh << 'SCRIPTEOF'
#!/bin/bash
set -a
source /etc/default/photo-album
set +a
envsubst '${BACKEND_HOST}' < /opt/nginx/photo-album.conf.template > /etc/nginx/sites-available/photo-album
SCRIPTEOF
sudo chmod +x /opt/nginx/generate-photo-album-config.sh

sudo sed -i 's|^ExecStart=.*|ExecStart=/opt/nginx/generate-photo-album-config.sh|' /etc/systemd/system/photo-album-nginx-config.service
sudo systemctl daemon-reload

# promtail: ExecStartPre 인라인 bash 도 깨지므로 스크립트로 대체
# 템플릿의 ${VAR:-default} 는 envsubst 가 못 쓰므로, sed 로 ${VAR} 로 바꾼 뒤 envsubst
sudo tee /opt/promtail/generate-config.sh << 'SCRIPTEOF'
#!/bin/bash
set -a
source /etc/default/promtail
set +a
export LOKI_LOGS_APP="${LOKI_LOGS_APP:-photo-frontend}"
export LOKI_LOGS_ENV="${LOKI_LOGS_ENV:-production}"
export INSTANCE_IP=$(hostname -I | cut -d" " -f1)
sed -e 's/\${LOKI_LOGS_APP:-[^}]*}/${LOKI_LOGS_APP}/g' -e 's/\${LOKI_LOGS_ENV:-[^}]*}/${LOKI_LOGS_ENV}/g' \
  /opt/promtail/promtail-config.yaml.template | envsubst > /opt/promtail/promtail-config.yaml
SCRIPTEOF
sudo chmod +x /opt/promtail/generate-config.sh
sudo sed -i 's|^ExecStartPre=.*|ExecStartPre=/opt/promtail/generate-config.sh|' /etc/systemd/system/promtail.service

# telegraf: override.conf 의 ExecStartPre 도 스크립트로 대체
# 템플릿의 ${VAR:-default} 는 envsubst 가 못 쓰므로, sed 로 ${VAR} 로 바꾼 뒤 envsubst
sudo tee /opt/telegraf/generate-config.sh << 'SCRIPTEOF'
#!/bin/bash
set -a
source /etc/default/telegraf
set +a
export INFLUX_APP="${INFLUX_APP:-photo-frontend}"
export INFLUX_ENV="${INFLUX_ENV:-production}"
export INSTANCE_IP=$(hostname -I | cut -d" " -f1)
sed -e 's/\${INFLUX_APP:-[^}]*}/${INFLUX_APP}/g' -e 's/\${INFLUX_ENV:-[^}]*}/${INFLUX_ENV}/g' \
  /opt/telegraf/telegraf.conf.template | envsubst > /opt/telegraf/telegraf.conf
SCRIPTEOF
sudo chmod +x /opt/telegraf/generate-config.sh
sudo sed -i 's|^ExecStartPre=.*|ExecStartPre=/opt/telegraf/generate-config.sh|' /etc/systemd/system/telegraf.service.d/override.conf

sudo systemctl daemon-reload

# 서비스 시작
sudo systemctl start nginx
sudo systemctl start promtail
sudo systemctl start telegraf
