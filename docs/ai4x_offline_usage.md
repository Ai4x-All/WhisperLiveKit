# 使用 Docker 镜像在ai4x离线环境启动与 WebSocket 前端调用

## 一、启动容器

## 准备文件

- 镜像已构建并推送到本地服务器：`crhz.ai4x.com.cn/whisperlivekit:latest`。  
- 模型已经下载到：`/data/whisper_models`
- 启动脚本 `run_wlk.sh` 放到任意位置 (如`/etc/apps/whisperlivekit`)

### 下载镜像

安装crane
```
curl -LO https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz
tar -zxvf go-containerregistry_Linux_x86_64.tar.gz
sudo mv crane /usr/local/bin/
```

```bash
# 先配置http_proxy或all_proxy环境变量
crane pull ghcr.io/ai4x-all/whisperlivekit:latest whisper_image.tar -v
# 推到本地registry
docker push whisperlivekit/whisperlivekit:latest
```

或一步完成
```bash
ALL_PROXY=socks5://10.... crane cp ghcr.io/ai4x-all/whisperlivekit:latest whisperlivekit/whisperlivekit:latest -v
```

### 准备模型

可直接复制需要的模型到目标服务器（例如客户服务器）`/data/whisper_models`目录。注意一定要成对复制，例如要使用medium模型，就要把`faster-whisper-medium` (CTranslate2 encoder)和`pytorch-whisper-base` (pytorch decoder)一起复制到目标服务器。

重新下载则要复制 `/scripts/download_models.sh`和`/scripts/download_decoder_pt.sh`到`/data/whisper_models`，设置好+x权限，并且运行它们：

```bash
./download_models.sh all
./download_decoder_pt.sh medium
# 参数可为 medium|large-v3|small|base
```


## 启动

启动命令：

`./run_wlk.sh medium`

- 可用的模型有: `base` | `small` | `medium` | `large-v3`

- 如果有问题，可以用前台启动调试：
`./run_wlk.sh medium -f`
- 修改`run_wlk.sh`里的`--gpus '"device=2"'`设置不同的显卡设备，`all`为不限设备。`nvidia-smi` 查询可用GPU。
- `--lan auto`是自动识别语言，可改为en, zh等语言


## 二、前端如何调用（AI 语音转写）

服务提供：

1. **HTTP**：`GET http://<host>:7100/` → 内置实时转写页面。
2. **WebSocket**：`ws://<host>:7100/asr` → 发送音频流，接收实时转写 JSON。


⚠️ 注意：如果地址不是`https://`或`https//localhost`，浏览器会禁止麦克风。需要在浏览器输入`edge://flags/#unsafely-treat-insecure-origin-as-secure`，在 `Insecure origins treated as secure`里填写本地服务器地址列表：`http://10.10.10.18:7100,http://10.10.10.2:7100`

### WebSocket 协议简述

- **连接**：`new WebSocket("ws://10.10.10.18:7100//asr")`。（公网域名很可能是`wss://`开头）
- **服务端→客户端**：
  - 连接后先收到一条 `{"type": "config", "useAudioWorklet": false}`。
  - 随后持续收到转写更新（JSON），例如包含 `type`、`lines`、`buffer_transcription`、`buffer_diarization` 等。
  - 全部音频处理完后会发 `{"type": "ready_to_stop"}`。
- **客户端→服务端**：只发**二进制**音频数据。
  - 默认使用 **WebM**（浏览器 `MediaRecorder` 录制的 `audio/webm` 块）直接发送。
  - 结束本轮会话：发送一个**空 Blob**（或空 ArrayBuffer），服务端处理完后会回 `ready_to_stop`。

更多字段说明见 [API.md](./API.md)。

### 多语言识别

在默认语言设置为auto时，WLK会以最初开始2秒识别的语言作为这个websocket连接的语言，后面不会再改变。如果要识别其他语言必须断开重连。

---

## 三、最小 WebSocket 示例（浏览器）

项目内已提供一个单页示例：**`docs/websocket-demo.html`**。

1. 用浏览器打开该文件（或放到同一台可访问 `http://10.10.10.18:7100/` 的 Web 服务器下）。
2. 在输入框填写：`ws://10.10.10.18:7100/asr`。
3. 点击「开始录音 / 转写」并允许麦克风，即可边说边看转写结果。

### 核心代码逻辑（复制即用）

```javascript
// 1. 连接
const ws = new WebSocket("ws://10.10.10.18:7100//asr");

// 2. 连接后先收到 config
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (msg.type === "config") {
    console.log("Server ready, useAudioWorklet:", msg.useAudioWorklet);
    return;
  }
  if (msg.type === "ready_to_stop") {
    console.log("Session ended.");
    return;
  }
  // 转写更新：msg.lines, msg.buffer_transcription, msg.buffer_diarization
  console.log("Transcript:", msg.lines, msg.buffer_transcription);
};

// 3. 获取麦克风并用 MediaRecorder 发送 WebM 块
const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
const recorder = new MediaRecorder(stream, { mimeType: "audio/webm" });
recorder.ondataavailable = (e) => {
  if (e.data.size > 0 && ws.readyState === WebSocket.OPEN) ws.send(e.data);
};
recorder.start(250); // 每 250ms 一块

// 4. 停止时发空 Blob 表示结束
recorder.stop();
ws.send(new Blob([], { type: "audio/webm" }));
```

若页面通过 HTTPS 访问，请将 WebSocket 改为 **wss**，并在服务器或反向代理上配置好 TLS 与 wss 转发。


## 后端为离线运行做的修改

为了实现离线运行，这个版本改动了下面的文件：
  - `whisperlivekit/parse_args.py`
  - `whisperlivekit/core.py`
  - `whisperlivekit/simul_whisper/backend.py` 

达到的效果：

- **Encoder**：从挂载的 `faster-whisper-*` 读 CTranslate2，本地。
- **Decoder**：从挂载的 `pytorch-whisper-*` 读 .pt（`--decoder-dir`），本地。
- **Warmup**：`--warmup-file ""` 关闭，不下载 jfk.wav。
- 未设置 `--decoder-dir` 时，当前实现会直接报错，不会回退到按名称下载。