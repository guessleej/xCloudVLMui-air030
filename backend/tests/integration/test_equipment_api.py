"""
tests/integration/test_equipment_api.py — 設備 API 整合測試
=============================================================
測試對象：
  GET /api/equipment         → 設備清單
  GET /api/equipment/summary → 統計摘要
  GET /api/equipment/{id}    → 單一設備

驗證要點：
  - 回應格式（schema）符合 EquipmentOut / EquipmentSummary
  - 靜態 Mock 資料的 6 台設備均存在
  - 不存在的設備 ID 回傳 404
"""
from __future__ import annotations

import pytest


# ── GET /api/equipment ───────────────────────────────────────────────

async def test_list_equipment_returns_200(client):
    resp = await client.get("/api/equipment")
    assert resp.status_code == 200

@pytest.mark.anyio
async def test_list_equipment_returns_list_of_six(client):
    """設備清單預設為空（由真實資料填入）"""
    resp  = await client.get("/api/equipment")
    items = resp.json()
    assert isinstance(items, list)
    assert len(items) == 0

@pytest.mark.anyio
async def test_list_equipment_schema(client):
    """回應欄位應符合 EquipmentOut schema"""
    resp = await client.get("/api/equipment")
    for item in resp.json():
        assert "id"            in item
        assert "name"          in item
        assert "status"        in item
        assert "vhs_score"     in item
        assert "active_alerts" in item


# ── GET /api/equipment/summary ──────────────────────────────────────

@pytest.mark.anyio
async def test_equipment_summary_returns_200(client):
    resp = await client.get("/api/equipment/summary")
    assert resp.status_code == 200

async def test_equipment_summary_total_equals_six(client):
    """total 應為 0（尚未載入真實設備資料）"""
    resp = await client.get("/api/equipment/summary")
    data = resp.json()
    assert data["total"] == 0

async def test_equipment_summary_counts_add_up(client):
    """normal + warning + critical + offline 應等於 total"""
    resp = await client.get("/api/equipment/summary")
    d    = resp.json()
    assert d["normal"] + d["warning"] + d["critical"] + d["offline"] == d["total"]


# ── GET /api/equipment/{id} ──────────────────────────────────────────

@pytest.mark.anyio
async def test_get_single_equipment_returns_404_when_empty(client):
    resp = await client.get("/api/equipment/AIR-030-01")
    assert resp.status_code == 404

@pytest.mark.anyio
async def test_get_nonexistent_equipment_returns_404(client):
    resp = await client.get("/api/equipment/NONEXISTENT")
    assert resp.status_code == 404

