#!/usr/bin/env bash
# 在有网机器上下载 PyTorch Whisper decoder .pt，供离线机挂载为 --decoder-dir。
# 用法: ./download_decoder_pt.sh <medium|large-v3|small|base>  下载到当前目录的 pytorch-whisper-<名>/

set -e
if [[ -z "$1" ]]; then
  echo "用法: $0 <medium|large-v3|small|base>"
  echo "示例: $0 medium"
  exit 1
fi
NAME="$1"
DIR="pytorch-whisper-$NAME"
mkdir -p "$DIR"
cd "$DIR"

# OpenAI 官方 URL（与 whisper/__init__.py _MODELS 一致）
declare -A URL=(
  [base]="https://openaipublic.azureedge.net/main/whisper/models/ed3a0b6b1c0edf879ad9b11b1af5a0e6ab5db9205f891f668f8b0e6c6326e34e/base.pt"
  [small]="https://openaipublic.azureedge.net/main/whisper/models/9ecf779972d90ba49c06d968637d720dd632c55bbf19d441fb42bf17a411e794/small.pt"
  [medium]="https://openaipublic.azureedge.net/main/whisper/models/345ae4da62f9b3d59415adc60127b97c714f32e89e936602e85993674d08dcb1/medium.pt"
  [large-v3]="https://openaipublic.azureedge.net/main/whisper/models/e5b1a55b89c1367dacf97e3e19bfd829a01529dbfdeefa8caeb59b3f1b81dadb/large-v3.pt"
)
u="${URL[$NAME]}"
if [[ -z "$u" ]]; then
  echo "不支持的模型: $NAME"
  exit 1
fi
OUT="${NAME}.pt"
echo "Downloading $u -> $OUT"
curl -L -o "$OUT" "$u"
echo "Done: $DIR/$OUT  拷到离线机 $MODELS_DIR/$DIR/ 后与 faster-whisper-$NAME 一起挂载启动。"
