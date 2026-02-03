# 인스턴스 이미지 빌드 및 배포

우분투 인스턴스 이미지(AMI)를 만들어 해당 이미지로 인스턴스를 실행하는 방법입니다.

## 1. 인스턴스 이미지 만들기

### 1.1 베이스 우분투 인스턴스 준비

- Ubuntu 22.04 LTS AMI로 인스턴스를 하나 실행합니다.
- 이 저장소를 클론합니다:
  ```bash
  git clone <repo-url> /opt/photo-frontend-repo
  cd /opt/photo-frontend-repo
  ```

### 1.2 이미지 빌드 스크립트 실행

```bash
sudo ./scripts/build-instance-image.sh
```

다음이 설치·구성됩니다.

| 항목 | 설명 |
|------|------|
| React 환경 | Node.js 18, npm (빌드용) |
| nginx | 설치 및 `/etc/nginx/sites-available/photo-album` 설정 (백엔드 주소는 placeholder) |
| Promtail | `/opt/promtail` 설치, 설정은 `conf/promtail-config.yaml` → `/opt/promtail/promtail-config.yaml` |
| Telegraf | `/opt/telegraf` 설치, 설정은 `conf/telegraf.conf` → `/opt/telegraf/telegraf.conf` |

### 1.3 AMI 생성

- AWS: 인스턴스 선택 → 작업 → 이미지 및 템플릿 → 이미지 생성
- CLI 예:
  ```bash
  aws ec2 create-image --instance-id i-xxxx --name "photo-frontend-image-$(date +%Y%m%d)"
  ```

## 2. 설정 파일 위치 (이미지 내)

- **Promtail**: `/opt/promtail/promtail-config.yaml` (소스: `conf/promtail-config.yaml`)
- **Telegraf**: `/opt/telegraf/telegraf.conf` (소스: `conf/telegraf.conf`)

Loki/InfluxDB 주소 등은 필요 시 인스턴스 기동 후 해당 경로의 파일을 수정하면 됩니다.

## 3. 이미지로 인스턴스 실행 (외부 배포)

### 3.1 AWS CLI 스크립트

```bash
export AMI_ID=ami-xxxxxxxx   # 1.3에서 만든 AMI ID
export KEY_NAME=my-key       # 선택
./scripts/launch-from-image.sh
# 또는
./scripts/launch-from-image.sh ami-xxxxxxxx
```

환경변수(선택): `AWS_REGION`, `INSTANCE_TYPE`, `KEY_NAME`, `SECURITY_GROUP_IDS`, `SUBNET_ID`, `NAME_TAG`

### 3.2 Terraform

```bash
cd scripts/terraform
cp photo-frontend-instance.tf.example main.tf
# main.tf 또는 terraform.tfvars 에 ami_id 등 설정
terraform init && terraform plan && terraform apply
```

## 4. 인스턴스 기동 후 앱 배포

1. 압축 파일을 `/opt/photo-frontend/` 에 업로드
2. `deploy.sh` 상단의 `BACKEND_UPSTREAM`, `BACKEND_HOST` 수정
3. 실행:
   ```bash
   cd /opt/photo-frontend && sudo ./deploy.sh
   ```

Promtail/Telegraf는 이미지에 포함된 systemd 서비스로 부팅 시 자동 시작됩니다. 필요 시 `systemctl start promtail`, `systemctl start telegraf` 로 수동 기동할 수 있습니다.
