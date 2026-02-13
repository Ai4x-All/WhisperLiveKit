#!/usr/bin/env bash
# 国内镜像下载 faster-whisper 模型到当前目录。
# 用法: ./download_models.sh <模型名|all>

set -e
export HF_ENDPOINT=https://hf-mirror.com
ALL="base small medium large-v3"

if [[ -z "$1" ]]; then
  echo "用法: $0 <模型名|all>"
  echo "示例: $0 base  或  $0 all"
  echo "模型: $ALL"
  exit 1
fi
MODELS="$1"

pip install -q huggingface_hub

download() {
  local name=$1
  echo "Downloading $name ..."
  python3 -c "
from huggingface_hub import snapshot_download
snapshot_download(repo_id='Systran/faster-whisper-$name', local_dir='./faster-whisper-$name')
" && echo "Done: ./faster-whisper-$name" || echo "Skip: $name"
}

if [[ "$MODELS" == "all" ]]; then
  for m in $ALL; do download "$m"; done
else
  download "$MODELS"
fi
