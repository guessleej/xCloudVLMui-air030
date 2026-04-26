<!-- xCloudVLMui — AIR-030 README -->
<div align="center">

# xCloudVLMui Platform — AIR-030

**工廠設備健康管理平台 · 工廠視覺 AI 指揮台**

[![Platform](https://img.shields.io/badge/Platform-Advantech%20AIR--030-orange)]()
[![SoM](https://img.shields.io/badge/SoM-Jetson%20AGX%20Orin-76b900?logo=nvidia&logoColor=white)]()
[![CUDA](https://img.shields.io/badge/CUDA-11.4%20Ampere-76b900?logo=nvidia&logoColor=white)]()
[![AI](https://img.shields.io/badge/AI-275%20TOPS%20INT8-ff6600)]()
[![RAM](https://img.shields.io/badge/RAM-64GB%20LPDDR5-blue)]()
[![Python](https://img.shields.io/badge/Python-3.11-3776ab?logo=python&logoColor=white)]()
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?logo=fastapi&logoColor=white)]()
[![Next.js](https://img.shields.io/badge/Next.js-14-000000?logo=nextdotjs&logoColor=white)]()
[![Docker](https://img.shields.io/badge/Docker-Compose%20v2-2496ED?logo=docker&logoColor=white)]()

> 由 **云碩科技 xCloudinfo Corp.Limited** 開發
> 專為 **Advantech AIR-030 / NVIDIA Jetson AGX Orin (64GB)** 優化的邊緣 AI 部署版本

</div>

---

## 硬體規格 — Advantech AIR-030

| 項目 | 規格 |
|------|------|
| **硬體平台** | Advantech AIR-030 Edge AI Computer |
| **SoM** | NVIDIA Jetson AGX Orin（64GB 版）|
| **CPU** | 12-core NVIDIA Arm Cortex-A78AE v8.2 64-bit |
| **GPU** | NVIDIA Ampere — 2,048 CUDA Cores + 64 Tensor Cores |
| **AI 效能** | **275 Sparse TOPS（INT8）**|
| **記憶體** | **64 GB 256-bit LPDDR5**（CPU + GPU 共享）68.7 GB/s |
| **儲存** | 64GB eMMC 5.1 + NVMe SSD 擴充槽 |
| **作業系統** | Ubuntu 20.04 LTS（L4T R35.x）|
| **JetPack** | 5.1 |
| **CUDA** | 11.4 |
| **TensorRT** | 8.5 |
| **cuDNN** | 8.6 |
| **網路** | 3× 2.5GbE（Intel I225-LM）|
| **USB** | USB 3.2 Gen2 |
| **功耗** | 15–60 W（可調整功耗模式）|

> Advantech AIR-030 搭載 NVIDIA Jetson AGX Orin 64GB，
> 是高效能、低功耗的工業級邊緣 AI 推論系統。

---

## 服務架構與 Port 配置

```
┌──────────────────────────────────────────────────────────────────┐
│                  AIR-030 / Jetson AGX Orin 64GB                  │
│                                                                  │
│  ┌─ [7] nginx :8780 ──────────────────────────────────────────┐  │
│  │                                                            │  │
│  │  ┌─ [6] frontend :3200 ─────────────────────────────────┐ │  │
│  │  │  Next.js 14 · 視覺巡檢 · MQTT · RAG · 模型管理       │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                            │  │
│  │  ┌─ [5] backend :8101 ──────────────────────────────────┐ │  │
│  │  │  FastAPI · SQLite · ChromaDB · RAG · MQTT             │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─ [3] llama-cpp :18180 ─────────────────────────────────────┐  │
│  │  Gemma 4 E4B Q4_K_M · CUDA 11.4 · Ampere GPU              │  │
│  │  n-gpu-layers=99 · ctx=32K · mlock                         │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─ [4] vlm-webui :8190 ──┐  ┌─ [2] mosquitto :1884 ─────────┐  │
│  │  WebRTC 視覺串流        │  │  MQTT Broker · IoT 感測器      │  │
│  └────────────────────────┘  └───────────────────────────────┘  │
│                                                                  │
│  ┌─ [8] cadvisor :8191 ───────────────────────────────────────┐  │
│  │  Ampere GPU + 容器資源監控                                  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

| 服務 | 外部 Port | 內部 Port | 說明 |
|------|-----------|-----------|------|
| nginx（主要入口）| **8780** | 80 | 反向代理統一入口 |
| nginx（HTTPS）| 8743 | 443 | SSL 入口 |
| backend API | 8101 | 8000 | FastAPI + RAG + MQTT |
| frontend | 3200 | 3000 | Next.js 儀表板 |
| llama-cpp | 18180 | 8080 | Ampere CUDA 推論 |
| vlm-webui | 8190 | 8090 | WebRTC 視覺串流 |
| cadvisor | 8191 | 8080 | 容器資源監控 |
| MQTT TCP | 1884 | 1883 | Eclipse Mosquitto |
| MQTT WS | 9002 | 9001 | MQTT over WebSocket |

---

## 快速部署

### 前置條件

```bash
# 1. 確認 JetPack / L4T 版本
cat /etc/nv_tegra_release
# 預期：# R35 (release) — JetPack 5.1

# 2. 確認 CUDA 版本
nvcc --version
# 預期：CUDA 11.4

# 3. 安裝 NVIDIA Container Toolkit
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 4. 設定最高效能模式（建議）
sudo nvpmodel -m 0     # MAXN 模式
sudo jetson_clocks     # 固定最高時脈
```

### 部署步驟

```bash
# 1. Clone 專案
git clone https://github.com/guessleej/xCloudVLMui-air030.git
cd xCloudVLMui-air030

# 2. 設定環境
make setup
# 編輯 backend/.env：填入 HF_TOKEN, SECRET_KEY
# 編輯 frontend/.env.local：填入 NEXTAUTH_SECRET, OAuth 憑證

# 3. 啟動所有服務
make up

# 4. 追蹤模型下載進度
make logs-llm

# 5. 驗證服務健康
make test
```

### 訪問介面

| 介面 | URL |
|------|-----|
| 主要 Web UI | `http://<AIR030_IP>:8780` |
| API 文件 | `http://<AIR030_IP>:8780/docs` |
| LLaMA.cpp | `http://<AIR030_IP>:18180/health` |
| cAdvisor | `http://<AIR030_IP>:8191` |

---

## Ampere GPU 推論設定

```yaml
# docker-compose.yml llama-cpp 關鍵參數
--n-gpu-layers 99    # 全部 Layer 上 GPU
--ctx-size 32768     # 32K context（64GB 記憶體配置）
--threads 12         # Cortex-A78AE × 12 核全部使用
--mlock              # 鎖定記憶體，零 swap
```

### 效能參考

| 項目 | 數值 |
|------|------|
| AI 算力 | 275 TOPS INT8 |
| 記憶體頻寬 | 68.7 GB/s |
| Context Window | 32K tokens |
| 功耗 | 15–60 W（可調）|

---

## 模型配置

| 模型 | 量化 | 大小 | 用途 |
|------|------|------|------|
| Gemma 4 E4B Q4_K_M | GGUF | ~4GB | LLM 問答 + VLM 推論 |
| YOLO11n detect (E2E) | ONNX | ~6MB | 設備巡檢 |
| YOLO11n pose (E2E) | ONNX | ~7MB | 人員辨識 |

---

## Jetson 效能監控

```bash
# 即時 GPU/CPU/記憶體監控
sudo tegrastats

# 查看效能模式
sudo nvpmodel -q

# 設定 MAXN 最高效能模式
sudo nvpmodel -m 0 && sudo jetson_clocks
```

---

## 故障排除

### NVIDIA Container Runtime 未配置
```bash
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### JetPack 5.1 Python 版本
```bash
# JetPack 5.1 預設 Python 3.8，建議升級
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get install -y python3.11 python3.11-venv
```

---

## 多平台總覽

| 平台 | 倉庫 | Port | 架構 | 推論加速 |
|------|------|------|------|----------|
| DGX Spark | [xCloudVLMui-dgx-spark](https://github.com/guessleej/xCloudVLMui-dgx-spark) | :8780 | ARM64 | GB10 CUDA 13 / DGX OS 7.4 |
| MIC-743 | [xCloudVLMui-mic743](https://github.com/guessleej/xCloudVLMui-mic743) | :8780 | ARM64 | Blackwell CUDA 12.6 / JetPack 7.x |
| **AIR-030** | **[xCloudVLMui-air030](https://github.com/guessleej/xCloudVLMui-air030)** | **:8780** | **ARM64** | **Ampere CUDA 11.4 / JetPack 5.1** |
| x86 | [xCloudVLMui-x86](https://github.com/guessleej/xCloudVLMui-x86) | :8680 | AMD64 | CPU / 可選 NVIDIA GPU |
| macOS | [xCloudVLMui-macOS](https://github.com/guessleej/xCloudVLMui-macOS) | :8880 | ARM64 | Ollama on Apple Silicon |

---

<div align="center">
由 <strong>云碩科技 xCloudinfo Corp.Limited</strong> 開發 · Powered by NVIDIA Jetson AGX Orin 64GB (Ampere · JetPack 5.1)
</div>
