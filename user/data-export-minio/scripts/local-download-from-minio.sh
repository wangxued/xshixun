#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MINIO_ENDPOINT="https://minio-data-xa.xshixun.cn:7443"
DEFAULT_MINIO_BUCKET="export"

usage() {
  cat <<'EOF'
用法：
  bash local-download-from-minio.sh <远端前缀> [本地目录]

示例：
  export AWS_ACCESS_KEY_ID='管理员发放的 access key'
  export AWS_SECRET_ACCESS_KEY='管理员发放的 secret key'
  bash local-download-from-minio.sh zhangsan/job-001 ./downloads

可选环境变量：
  MINIO_ENDPOINT   默认公网下载地址
  MINIO_BUCKET     默认 export
  MC_BIN           默认 mc；可指定 /path/to/mc
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "错误：未找到命令 $1，请先安装 MinIO Client(mc)。" >&2
    exit 1
  fi
}

require_env() {
  local value="$1"
  local name="$2"
  if [ -z "$value" ]; then
    echo "错误：请先设置 ${name}。" >&2
    exit 1
  fi
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

remote_prefix="$1"
local_dir="${2:-./minio-downloads}"
minio_endpoint="${MINIO_ENDPOINT:-$DEFAULT_MINIO_ENDPOINT}"
minio_bucket="${MINIO_BUCKET:-$DEFAULT_MINIO_BUCKET}"
mc_bin="${MC_BIN:-mc}"

require_command "$mc_bin"
require_env "${AWS_ACCESS_KEY_ID:-}" "AWS_ACCESS_KEY_ID"
require_env "${AWS_SECRET_ACCESS_KEY:-}" "AWS_SECRET_ACCESS_KEY"

mkdir -p "$local_dir"

echo "下载来源：s3://${minio_bucket}/${remote_prefix}"
echo "下载目录：$local_dir"

"$mc_bin" alias set data-minio "$minio_endpoint" "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"
"$mc_bin" cp --recursive "data-minio/${minio_bucket}/${remote_prefix}" "$local_dir/"

echo "下载完成。"
