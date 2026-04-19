# xCloudVLMui — AIR-030 JetPack 6.0 部署指南

> **目標平台**：Advantech AIR-030  
> **SoM**：NVIDIA Jetson AGX Orin 64GB  
> **OS**：NVIDIA JetPack 6.0 (L4T R36.3.0)  
> **架構**：ARM64 (aarch64)  
> **加速**：CUDA 12.2 · TensorRT 10.x · cuDNN 9.x  

---

## 硬體規格

| 項目 | 規格 |
|------|------|
| 硬體平台 | Advantech AIR-030 Edge AI System |
| SoM | Jetson AGX Orin 64GB |
| CPU | 12-core Arm Cortex-A78AE v8.2 64-bit |
| GPU | 2048-core Ampere GPU + 64 Tensor Cores |
| AI 加速 | 2x NVDLA v3.0 + 2x PVA v2.0 |
| 記憶體 | 64GB LPDDR5 unified memory |
| 作業系統 | Ubuntu 22.04 (L4T R36.3.0) |
| CUDA | 12.2 |
| JetPack | 6.0 |

## 服務 Port 配置

| 服務 | 外部 Port | 說明 |
|------|-----------|------|
| nginx (主要入口) | **8880** | 反向代理 |
| backend API | 8001 | FastAPI |
| frontend | 3100 | Next.js 儀表板 |
| llama-cpp | 18080 | Gemma 4 E4B CUDA 推論 |
| vlm-webui | 8090 | WebRTC 視覺串流 |
| cadvisor | 8091 | 容器資源監控 |
| MQTT | 1883 / 9001 | Eclipse Mosquitto |

## 快速部署

```bash
# Clone 專案
git clone https://github.com/guessleej/xCloudVLMui-air030.git
cd xCloudVLMui-air030

# 設定環境
make setup
# 編輯 backend/.env：填入 HF_TOKEN、SECRET_KEY
# 編輯 frontend/.env.local：填入 OAuth 憑證、AIR-030 IP

# 啟動（首次約 10 分鐘，需下載模型）
make up

# 驗證服務
make test
```

## JetPack 6.0 前置設定

```bash
# 確認版本
cat /etc/nv_tegra_release
# 預期：# R36 (release), REVISION: 3.0

# 安裝 NVIDIA Container Toolkit
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 最高效能模式
sudo nvpmodel -m 0   # MAXN
sudo jetson_clocks
```

## llama.cpp GPU 設定

```
--n-gpu-layers 99   # 全部層載入 GPU（AGX Orin 64GB 足夠）
--flash-attn        # FlashAttention 加速
--ctx-size 131072   # 128K context
--threads 8         # CPU 輔助執行緒
```

## 模型配置

| 模型 | 量化 | 大小 | 推論引擎 |
|------|------|------|----------|
| Gemma 4 E4B Q4_K_M | GGUF | ~4GB | llama.cpp CUDA |
| YOLO26n detect | E2E ONNX | ~6MB | WASM 前端 |
| YOLO26n pose | E2E ONNX | ~7MB | WASM 前端 |

## Jetson 效能監控

```bash
# 即時監控
sudo tegrastats

# 查看效能模式
sudo nvpmodel -q
```

## GitHub 倉庫

此倉庫專用於 AIR-030 (JetPack 6.0) 平台部署：  
**`https://github.com/guessleej/xCloudVLMui-air030`**

---

## 四平台總覽

| 平台 | 倉庫 | Port | 加速 |
|------|------|------|------|
| macOS | xCloudVLMui | :3110 | CPU / Apple Silicon |
| **AIR-030** | **xCloudVLMui-air030** | **:8880** | **CUDA 12.2 / JetPack 6.0** |
| MIC-743 | xCloudVLMui-mic743 | :8780 | CUDA 12.6 / JetPack 7.1 |
| x86 | xCloudVLMui-x86 | :8680 | CPU / 可選 NVIDIA GPU |
