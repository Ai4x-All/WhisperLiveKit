#!/usr/bin/env bash
# 完全离线启动 WhisperLiveKit：挂载 CTranslate2 模型 + PyTorch decoder 目录，禁用 warmup 下载。
# 用法: ./run_wlk.sh [medium|large-v3|small|base] [-f|--foreground]
# 默认 medium、后台(-d)。加 -f 或 --foreground 前台运行便于调试。
# 需提前准备: faster-whisper-<名> 与 pytorch-whisper-<名>（见 docs/offline-run.md）

set -e
FOREGROUND=""
while [[ "$1" == "-f" || "$1" == "--foreground" ]]; do FOREGROUND=1; shift; done
MODEL="${1:-medium}"
if [[ "$2" == "-f" || "$2" == "--foreground" ]]; then FOREGROUND=1; fi
DETACH="-d"
[[ -n "$FOREGROUND" ]] && DETACH=""

MODELS_DIR="/data/whisper_models"
IMAGE="crhz.ai4x.com.cn/whisperlivekit:latest"
PORT=7100

MODEL_DIR="$MODELS_DIR/faster-whisper-$MODEL"
DECODER_DIR="$MODELS_DIR/pytorch-whisper-$MODEL"
CONTAINER_MODEL_PATH="/models/faster-whisper-$MODEL"
CONTAINER_DECODER_PATH="/models/pytorch-whisper-$MODEL"

if [[ ! -d "$MODEL_DIR" ]]; then
  echo "模型目录不存在: $MODEL_DIR"
  exit 1
fi
if [[ ! -d "$DECODER_DIR" ]]; then
  echo "Decoder 目录不存在: $DECODER_DIR（离线必须预置 PyTorch .pt）"
  echo "可选: base, small, medium, large-v3  需同时具备 faster-whisper-<名> 与 pytorch-whisper-<名>"
  exit 1
fi

docker run $DETACH --rm \
  --gpus '"device=2"' \
  -p "$PORT:8000" \
  -v "$MODEL_DIR:$CONTAINER_MODEL_PATH:ro" \
  -v "$DECODER_DIR:$CONTAINER_DECODER_PATH:ro" \
  --name "wlk-$MODEL" \
  "$IMAGE" \
  --model-path "$CONTAINER_MODEL_PATH" --decoder-dir "$CONTAINER_DECODER_PATH" --warmup-file "" --lan auto

if [[ -n "$DETACH" ]]; then
  echo "已启动(离线): 模型=$MODEL, 端口=$PORT, 容器名=wlk-$MODEL"
else
  echo "前台运行(调试): 模型=$MODEL, 端口=$PORT   Ctrl+C 退出"
fi
