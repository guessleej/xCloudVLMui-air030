###############################################################################
# Makefile — xCloudVLMui Platform [bot-air030]
# Advantech AIR-030 · Jetson AGX Orin 64GB · JetPack 6.0 · ARM64 · CUDA 12.2
#
# ┌─ 首次部署 ──────────────────────────────────────────────────────────┐
# │  make setup        # 複製 .env，確認 GPU runtime                    │
# │  make up           # 啟動所有 Docker 服務（含 CUDA 加速）           │
# │  make test         # 驗證所有服務健康狀態                           │
# └────────────────────────────────────────────────────────────────────┘
#
# Port 配置（bot-air030 專用）：
#   nginx    → http://localhost:8880  ← 主要入口
#   backend  → http://localhost:8001/api/health
#   llama-cpp→ http://localhost:18080/health
#   vlm-webui→ http://localhost:8090
#   cadvisor → http://localhost:8091
###############################################################################

.PHONY: all help setup check-gpu up down restart \
        logs logs-llm logs-backend logs-frontend logs-mqtt \
        status test ps clean clean-all

COMPOSE      := docker compose
COMPOSE_FILE := -f docker-compose.yml
HOST ?= localhost

BLUE   := \033[0;34m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

all: help

help:
	@echo ""
	@printf "$(BLUE)╔══════════════════════════════════════════════════════════╗$(NC)\n"
	@printf "$(BLUE)║  xCloudVLMui — AIR-030 · JetPack 6.0 · ARM64 · CUDA 12.2 ║$(NC)\n"
	@printf "$(BLUE)╠══════════════════════════════════════════════════════════╣$(NC)\n"
	@printf "$(BLUE)║  nginx:8880  backend:8001  frontend:3100  llama:18080     ║$(NC)\n"
	@printf "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)\n"
	@echo ""
	@printf "$(YELLOW)首次部署：$(NC)\n"
	@printf "  make setup          複製 .env 並確認 NVIDIA GPU runtime\n"
	@printf "  make up             建置並啟動所有服務（CUDA 加速）\n"
	@printf "  make test           驗證所有服務健康狀態\n"
	@echo ""
	@printf "$(YELLOW)日常操作：$(NC)\n"
	@printf "  make logs           查看所有服務 log\n"
	@printf "  make logs-llm       只看 llama-cpp log（GPU 推論）\n"
	@printf "  make logs-backend   只看 backend log\n"
	@printf "  make status         顯示容器狀態\n"
	@printf "  make check-gpu      確認 Jetson GPU / JetPack 版本\n"
	@printf "  make restart        重啟所有服務\n"
	@printf "  make down           停止容器\n"
	@printf "  make clean          停止並移除容器（保留資料）\n"
	@printf "  make clean-all      完全清除（含 Volume 資料庫）\n"
	@echo ""

# ─────────────────────────────────────────────────────────────────────
setup:
	@printf "$(BLUE)► 設定 AIR-030 環境...$(NC)\n"
	@if [ ! -f backend/.env ]; then \
		cp backend/.env.example backend/.env ; \
		printf "$(YELLOW)  ⚠ 已複製 backend/.env，請填入 HF_TOKEN / SECRET_KEY。$(NC)\n" ; \
	else \
		printf "$(GREEN)  ✓ backend/.env 已存在。$(NC)\n" ; \
	fi
	@if [ ! -f frontend/.env.local ]; then \
		cp frontend/.env.local.example frontend/.env.local ; \
		printf "$(YELLOW)  ⚠ 已複製 frontend/.env.local，請填入 OAuth 憑證與 AIR-030 IP。$(NC)\n" ; \
	else \
		printf "$(GREEN)  ✓ frontend/.env.local 已存在。$(NC)\n" ; \
	fi
	@$(MAKE) check-gpu
	@printf "$(GREEN)✓ setup 完成！執行 make up 啟動服務。$(NC)\n"

check-gpu:
	@printf "$(BLUE)► 確認 Jetson GPU 環境...$(NC)\n"
	@if command -v tegrastats > /dev/null 2>&1; then \
		printf "$(GREEN)  ✓ tegrastats 可用（JetPack 已安裝）$(NC)\n" ; \
	else \
		printf "$(YELLOW)  ⚠ tegrastats 未找到，確認 JetPack 6.0 安裝$(NC)\n" ; \
	fi
	@if docker info --format '{{.Runtimes}}' 2>/dev/null | grep -q nvidia; then \
		printf "$(GREEN)  ✓ NVIDIA Container Runtime 已配置$(NC)\n" ; \
	else \
		printf "$(RED)  ✗ NVIDIA Container Runtime 未配置！$(NC)\n" ; \
		printf "    sudo apt install nvidia-container-toolkit && sudo systemctl restart docker\n" ; \
	fi

# ─────────────────────────────────────────────────────────────────────
build:
	$(COMPOSE) $(COMPOSE_FILE) build --parallel

up:
	@printf "$(BLUE)► 啟動 AIR-030 服務（CUDA 12.2 GPU 加速）...$(NC)\n"
	$(COMPOSE) $(COMPOSE_FILE) up -d --build
	@echo ""
	@printf "$(GREEN)✓ 服務已啟動！$(NC)\n\n"
	@printf "  主要入口  → $(BLUE)http://localhost:8880$(NC)\n"
	@printf "  API Docs  → $(BLUE)http://localhost:8880/docs$(NC)\n"
	@printf "  Backend   → $(BLUE)http://localhost:8001/api/health$(NC)\n"
	@printf "  Frontend  → $(BLUE)http://localhost:3100$(NC)\n"
	@printf "  LLaMA.cpp → $(BLUE)http://localhost:18080/health$(NC)\n"
	@printf "  VLM WebUI → $(BLUE)http://localhost:8090$(NC)\n"
	@printf "  cAdvisor  → $(BLUE)http://localhost:8091$(NC)\n"

down:
	$(COMPOSE) $(COMPOSE_FILE) down

restart:
	$(COMPOSE) $(COMPOSE_FILE) restart

logs:
	$(COMPOSE) $(COMPOSE_FILE) logs -f --tail=100

logs-llm:
	$(COMPOSE) $(COMPOSE_FILE) logs -f --tail=100 llama-cpp

logs-backend:
	$(COMPOSE) $(COMPOSE_FILE) logs -f --tail=100 backend

logs-frontend:
	$(COMPOSE) $(COMPOSE_FILE) logs -f --tail=100 frontend

logs-mqtt:
	$(COMPOSE) $(COMPOSE_FILE) logs -f --tail=100 mosquitto

ps:
	$(COMPOSE) $(COMPOSE_FILE) ps

status:
	@printf "$(BLUE)── AIR-030 容器狀態 ──────────────────$(NC)\n"
	$(COMPOSE) $(COMPOSE_FILE) ps

test:
	@printf "$(BLUE)► 驗證 AIR-030 服務健康狀態（HOST=$(HOST)）...$(NC)\n"
	@for url in \
		"http://$(HOST):8000/api/health" \
		"http://$(HOST):8080/health" \
		"http://$(HOST)/api/health" \
		"http://$(HOST):8091/healthz"; do \
		CODE=$$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 $$url 2>/dev/null || echo "ERR") ; \
		if [ "$$CODE" = "200" ]; then \
			printf "  $(GREEN)✓$(NC) %-50s → %s\n" "$$url" "$$CODE" ; \
		else \
			printf "  $(RED)✗$(NC) %-50s → %s\n" "$$url" "$$CODE" ; \
		fi ; \
	done

clean:
	$(COMPOSE) $(COMPOSE_FILE) down --rmi local
	@printf "$(GREEN)✓ 容器已清除（資料 Volume 保留）。$(NC)\n"

clean-all:
	@printf "$(RED)⚠ 這將刪除 AIR-030 所有資料，包含模型與資料庫！$(NC)\n"
	@printf "$(YELLOW)確認？(y/N) $(NC)" ; read confirm ; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		$(COMPOSE) $(COMPOSE_FILE) down -v --rmi local ; \
		printf "$(GREEN)✓ 完全清除完成。$(NC)\n" ; \
	else \
		printf "已取消。\n" ; \
	fi

shell-backend:
	$(COMPOSE) $(COMPOSE_FILE) exec backend /bin/bash

shell-frontend:
	$(COMPOSE) $(COMPOSE_FILE) exec frontend /bin/sh
