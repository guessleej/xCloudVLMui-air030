"""
tests/integration/test_vhs_api.py — VHS 設備健康分數 API 整合測試
================================================================
測試對象：
    POST /api/vhs/readings              — 新增 VHS 讀值
    GET  /api/vhs/trend/{equipment_id}  — 取得指定設備 VHS 趨勢

驗證要點：
    - 寫入 VHS 讀值成功
    - score 範圍驗證（0–100）
    - 趨勢查詢回應格式正確
"""
from __future__ import annotations

import pytest


# ── Helpers ──────────────────────────────────────────────────────────

def _vhs_payload(
    equipment_id: str  = "EQ-TEST-001",
    score:        float = 75.5,
    source:       str  = "manual",
    notes:        str  = "單元測試讀值",
) -> dict:
    return {
        "equipment_id": equipment_id,
        "score":        score,
        "source":       source,
        "notes":        notes,
    }


# ── POST /api/vhs/readings ───────────────────────────────────────────

@pytest.mark.anyio
async def test_create_vhs_reading_returns_201(client):
    resp = await client.post("/api/vhs/readings", json=_vhs_payload())
    assert resp.status_code == 201


@pytest.mark.anyio
async def test_create_vhs_reading_schema(client):
    """回應應包含所有必填欄位"""
    resp = await client.post("/api/vhs/readings", json=_vhs_payload())
    data = resp.json()
    for field in ["id", "equipment_id", "score", "source", "recorded_at"]:
        assert field in data, f"Missing field: {field}"


@pytest.mark.anyio
async def test_create_vhs_reading_persists_correct_values(client):
    """寫入的值應正確保存"""
    payload = _vhs_payload(equipment_id="EQ-PERSIST-001", score=88.3, source="vlm")
    resp    = await client.post("/api/vhs/readings", json=payload)
    data    = resp.json()
    assert data["equipment_id"] == "EQ-PERSIST-001"
    assert data["score"]        == pytest.approx(88.3, abs=0.01)
    assert data["source"]       == "vlm"


@pytest.mark.anyio
async def test_create_vhs_reading_invalid_score_high(client):
    """score > 100 應回傳 422（Pydantic 驗證失敗）"""
    resp = await client.post("/api/vhs/readings", json=_vhs_payload(score=101.0))
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_create_vhs_reading_invalid_score_low(client):
    """score < 0 應回傳 422"""
    resp = await client.post("/api/vhs/readings", json=_vhs_payload(score=-1.0))
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_create_vhs_reading_boundary_score_zero(client):
    """score = 0.0（邊界值）應成功"""
    resp = await client.post("/api/vhs/readings", json=_vhs_payload(score=0.0))
    assert resp.status_code == 201
    assert resp.json()["score"] == pytest.approx(0.0)


@pytest.mark.anyio
async def test_create_vhs_reading_boundary_score_hundred(client):
    """score = 100.0（邊界值）應成功"""
    resp = await client.post("/api/vhs/readings", json=_vhs_payload(score=100.0))
    assert resp.status_code == 201
    assert resp.json()["score"] == pytest.approx(100.0)


# ── GET /api/vhs/trend/{equipment_id} ───────────────────────────────

@pytest.mark.anyio
async def test_vhs_trend_returns_200(client):
    eq_id = "EQ-TREND-001"
    await client.post("/api/vhs/readings", json=_vhs_payload(equipment_id=eq_id, score=72.0))

    resp = await client.get(f"/api/vhs/trend/{eq_id}")
    assert resp.status_code == 200


@pytest.mark.anyio
async def test_vhs_trend_schema(client):
    eq_id = "EQ-TREND-SCHEMA-001"
    await client.post("/api/vhs/readings", json=_vhs_payload(equipment_id=eq_id, score=66.6))

    resp = await client.get(f"/api/vhs/trend/{eq_id}")
    data = resp.json()
    for field in ["equipment_id", "days", "real_days", "estimated_days", "data"]:
        assert field in data, f"Missing field: {field}"
    assert data["equipment_id"] == eq_id
    assert isinstance(data["data"], list)
