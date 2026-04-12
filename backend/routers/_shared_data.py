"""
routers/_shared_data.py — 跨 Router 共用的設備資料輔助模組

說明：
  - _EQUIPMENT 為空清單；設備資料應由真實 DB / MQTT 寫入產生
  - 種子函式已移除（不再自動植入假資料）
  - estimate_vhs_score 保留供 VHS 趨勢計算使用
"""
from __future__ import annotations

import math
from models.schemas import EquipmentOut

# ── 設備清單（空；由真實資料填入）────────────────────────────────────
_EQUIPMENT: list[EquipmentOut] = []


def estimate_vhs_score(base: float, day_offset: int, total_days: int) -> float:
    """根據設備當前分數估算歷史趨勢（確定性計算，無隨機）"""
    decay     = day_offset * (100 - base) / (total_days * 6)
    variation = math.sin(day_offset * 0.7) * 3
    return round(max(5.0, min(100.0, base - decay + variation)), 1)
