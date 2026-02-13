#!/usr/bin/env bash
# 完全离线启动 WhisperLiveKit：挂载 CTranslate2 模型 + PyTorch decoder 目录，禁用 warmup 下载。
# 用法: ./run_wlk.sh [medium|large-v3|small|base] [-f|--foreground]
# 默认 medium、后台(-d)。加 -f 或 --foreground 前台运行便于调试。
# 需提前准备: faster-whisper-<名> 与 pytorch-whisper-<名>；补丁目录含 parse_args.py、core.py、backend.py（见 docs/offline-run.md）

set -e
FOREGROUND=""
while [[ "$1" == "-f" || "$1" == "--foreground" ]]; do FOREGROUND=1; shift; done
MODEL="${1:-medium}"
if [[ "$2" == "-f" || "$2" == "--foreground" ]]; then FOREGROUND=1; fi
DETACH="-d"
[[ -n "$FOREGROUND" ]] && DETACH=""

MODELS_DIR="/data/whisper_models"
PATCH_DIR="${PATCH_DIR:-/etc/apps/whisperlivekit}"
IMAGE="crhz.ai4x.com.cn/whisperlivekit:latest"
PKG="/opt/venv/lib/python3.12/site-packages/whisperlivekit"
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
# 离线需挂载三处补丁（支持 --decoder-dir），缺一不可
PARSE_ARGS="$PATCH_DIR/parse_args.py"
CORE_PY="$PATCH_DIR/core.py"
BACKEND_PY="$PATCH_DIR/backend.py"
for f in "$PARSE_ARGS" "$CORE_PY" "$BACKEND_PY"; do
  if [[ ! -f "$f" ]]; then
    echo "未找到补丁: $f（需将 parse_args.py、core.py、backend.py 放到 $PATCH_DIR）"
    exit 1
  fi
done

docker run $DETACH --rm \
  --gpus '"device=2"' \
  -p "$PORT:8000" \
  -v "$MODEL_DIR:$CONTAINER_MODEL_PATH:ro" \
  -v "$DECODER_DIR:$CONTAINER_DECODER_PATH:ro" \
  -v "$PARSE_ARGS:$PKG/parse_args.py:ro" \
  -v "$CORE_PY:$PKG/core.py:ro" \
  -v "$BACKEND_PY:$PKG/simul_whisper/backend.py:ro" \
  --name "wlk-$MODEL" \
  "$IMAGE" \
  --model-path "$CONTAINER_MODEL_PATH" --decoder-dir "$CONTAINER_DECODER_PATH" --warmup-file "" --lan auto

if [[ -n "$DETACH" ]]; then
  echo "已启动(离线): 模型=$MODEL, 端口=$PORT, 容器名=wlk-$MODEL"
else
  echo "前台运行(调试): 模型=$MODEL, 端口=$PORT   Ctrl+C 退出"
fi
