#!/usr/bin/env bash
###############################################################################
# download-model.sh
# 下載 Gemma 4 E2B GGUF Q4_K_S 與 mmproj 至 ./models/
#
# 用法：
#   bash scripts/download-model.sh             # 互動確認
#   bash scripts/download-model.sh --yes       # 無人值守
#   HF_TOKEN=xxx bash scripts/download-model.sh --yes  # Private model
###############################################################################
set -euo pipefail

MODELS_DIR="$(cd "$(dirname "$0")/.." && pwd)/models"
MODEL_FILENAME="gemma-4-E2B-it-Q4_K_S.gguf"
MODEL_PATH="${MODELS_DIR}/${MODEL_FILENAME}"
MMPROJ_DIR="${MODELS_DIR}/gemma-4-e2b-it"
MMPROJ_FILENAME="mmproj.gguf"
MMPROJ_SOURCE_FILENAME="mmproj-BF16.gguf"
MMPROJ_PATH="${MMPROJ_DIR}/${MMPROJ_FILENAME}"

HF_REPO="unsloth/gemma-4-E2B-it-GGUF"
HF_FILE="${MODEL_FILENAME}"
HF_URL="https://huggingface.co/${HF_REPO}/resolve/main/${HF_FILE}"
HF_MMPROJ_URL="https://huggingface.co/${HF_REPO}/resolve/main/${MMPROJ_SOURCE_FILENAME}"

# 顏色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     Gemma 4 E2B GGUF Q4_K_S — 模型下載程式          ║"
echo "║     AIR-030 × Jetson AGX Orin 64GB × JetPack 6.0    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "  來源：${YELLOW}${HF_URL}${NC}"
echo -e "  目標：${YELLOW}${MODEL_PATH}${NC}"
echo -e "  MMProj：${YELLOW}${HF_MMPROJ_URL}${NC}"
echo -e "  大小：約 ${YELLOW}2.9 GB${NC}（Q4_K_S 量化）+ ${YELLOW}~1 GB${NC} mmproj"
echo ""

# 建立目錄
mkdir -p "${MODELS_DIR}" "${MMPROJ_DIR}"

# 若已存在則跳過
if [[ -f "${MODEL_PATH}" && -f "${MMPROJ_PATH}" ]]; then
  SIZE=$(du -sh "${MODEL_PATH}" | cut -f1)
  MMPROJ_SIZE=$(du -sh "${MMPROJ_PATH}" | cut -f1)
  echo -e "${GREEN}✓ 模型與 mmproj 已存在（${SIZE} + ${MMPROJ_SIZE}），跳過下載。${NC}"
  echo -e "  路徑：${MODEL_PATH}"
  echo -e "  MMProj：${MMPROJ_PATH}"
  exit 0
fi

# 確認提示
if [[ "${1:-}" != "--yes" ]]; then
  echo -ne "${YELLOW}確認下載？(y/N) ${NC}"
  read -r confirm
  [[ "${confirm}" =~ ^[Yy]$ ]] || { echo "已取消。"; exit 0; }
fi

echo ""
echo -e "${BLUE}開始下載...${NC}"

# ── 方法 1：huggingface-cli（推薦，有斷點續傳）────────────────────
if command -v huggingface-cli &>/dev/null; then
  echo -e "  使用 ${GREEN}huggingface-cli${NC}（支援斷點續傳）"
  HF_TOKEN_ARG=""
  [[ -n "${HF_TOKEN:-}" ]] && HF_TOKEN_ARG="--token ${HF_TOKEN}"
  if [[ ! -f "${MODEL_PATH}" ]]; then
    huggingface-cli download \
      ${HF_REPO} \
      ${HF_FILE} \
      --local-dir "${MODELS_DIR}" \
      --local-dir-use-symlinks False \
      ${HF_TOKEN_ARG}
  fi
  if [[ ! -f "${MMPROJ_PATH}" ]]; then
    huggingface-cli download \
      ${HF_REPO} \
      ${MMPROJ_SOURCE_FILENAME} \
      --local-dir "${MMPROJ_DIR}" \
      --local-dir-use-symlinks False \
      ${HF_TOKEN_ARG}
    mv -f "${MMPROJ_DIR}/${MMPROJ_SOURCE_FILENAME}" "${MMPROJ_PATH}"
  fi

# ── 方法 2：wget（有進度條）──────────────────────────────────────
elif command -v wget &>/dev/null; then
  echo -e "  使用 ${GREEN}wget${NC}"
  HEADER_ARG=""
  [[ -n "${HF_TOKEN:-}" ]] && HEADER_ARG="--header=Authorization: Bearer ${HF_TOKEN}"
  [[ -f "${MODEL_PATH}" ]] || wget -c ${HEADER_ARG} \
      --show-progress \
      -O "${MODEL_PATH}" \
      "${HF_URL}"
  [[ -f "${MMPROJ_PATH}" ]] || wget -c ${HEADER_ARG} \
      --show-progress \
      -O "${MMPROJ_PATH}" \
      "${HF_MMPROJ_URL}"

# ── 方法 3：curl ──────────────────────────────────────────────────
elif command -v curl &>/dev/null; then
  echo -e "  使用 ${GREEN}curl${NC}"
  HEADER_ARG=""
  [[ -n "${HF_TOKEN:-}" ]] && HEADER_ARG="-H \"Authorization: Bearer ${HF_TOKEN}\""
  [[ -f "${MODEL_PATH}" ]] || curl -L --continue-at - \
      ${HEADER_ARG} \
      --progress-bar \
      -o "${MODEL_PATH}" \
      "${HF_URL}"
  [[ -f "${MMPROJ_PATH}" ]] || curl -L --continue-at - \
      ${HEADER_ARG} \
      --progress-bar \
      -o "${MMPROJ_PATH}" \
      "${HF_MMPROJ_URL}"

else
  echo -e "${RED}✗ 錯誤：找不到 huggingface-cli / wget / curl${NC}"
  echo "  請安裝其中一個工具，或手動下載：${HF_URL}"
  exit 1
fi

# 驗證檔案
if [[ -f "${MODEL_PATH}" && -f "${MMPROJ_PATH}" ]]; then
  SIZE=$(du -sh "${MODEL_PATH}" | cut -f1)
  MMPROJ_SIZE=$(du -sh "${MMPROJ_PATH}" | cut -f1)
  echo ""
  echo -e "${GREEN}✓ 下載完成！（${SIZE} + ${MMPROJ_SIZE}）${NC}"
  echo -e "  ${MODEL_PATH}"
  echo -e "  ${MMPROJ_PATH}"
else
  echo -e "${RED}✗ 下載失敗，請手動下載：${NC}"
  echo -e "  ${HF_URL}"
  echo -e "  ${HF_MMPROJ_URL} → ${MMPROJ_PATH}"
  exit 1
fi
