"""
routers/vhs.py — VHS 健康評分 API
職責：VHS 趨勢查詢、手動 / VLM 評分寫入

端點：
  GET  /api/vhs/trend/{equipment_id}  → 取得 14 天 VHS 趨勢（DB 優先，缺日補估算）
  POST /api/vhs/readings              → 寫入 VHS 評分（手動 / vlm / seed）

來源優先順序（source priority）：
  vlm > manual > seed > estimated
"""
from __future__ import annotations

from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.db_models import VhsReading
from models.schemas import VhsDataPoint, VhsReadingCreate, VhsReadingOut, VhsTrendMeta
from routers._shared_data import estimate_vhs_score

import uuid

router = APIRouter(prefix="/api/vhs", tags=["vhs"])

# 來源優先順序：數字越小優先級越高
_SOURCE_PRIORITY: dict[str, int] = {"vlm": 0, "manual": 1, "seed": 2, "estimated": 9}


@router.get("/trend/{equipment_id}", response_model=VhsTrendMeta)
async def get_vhs_trend(
    equipment_id: str,
    days:         int = 14,
    db:           AsyncSession = Depends(get_db),
):
    """
    VHS 趨勢：取得指定設備最近 N 天的健康評分。
    - 有 DB 記錄的日期：使用真實值（每日平均，來源取優先級最高者）
    - 缺少的日期：回傳空點（score=None），前端自行處理
    """
    now   = datetime.now(timezone.utc)
    since = now - timedelta(days=days)

    result = await db.execute(
        select(VhsReading)
        .where(
            VhsReading.equipment_id == equipment_id,
            VhsReading.recorded_at  >= since,
        )
        .order_by(VhsReading.recorded_at.asc())
    )
    readings = result.scalars().all()

    # 建立日期 → (avg_score, count, best_source) 字典
    day_map: dict[str, tuple[float, int, str]] = {}
    for r in readings:
        key = r.recorded_at.strftime("%m/%d")
        if key not in day_map:
            day_map[key] = (r.score, 1, r.source)
        else:
            prev_score, prev_cnt, prev_src = day_map[key]
            new_avg = (prev_score * prev_cnt + r.score) / (prev_cnt + 1)
            # 取優先級較高的來源
            best_src = (
                r.source if _SOURCE_PRIORITY.get(r.source, 9) < _SOURCE_PRIORITY.get(prev_src, 9)
                else prev_src
            )
            day_map[key] = (round(new_avg, 1), prev_cnt + 1, best_src)

    # 組裝完整時間軸
    data: list[VhsDataPoint] = []
    real_days = 0

    for i in range(days):
        day = now - timedelta(days=days - i - 1)
        key = day.strftime("%m/%d")

        if key in day_map:
            avg_score, cnt, src = day_map[key]
            data.append(VhsDataPoint(
                timestamp=     key,
                score=         avg_score,
                equipment_id=  equipment_id,
                source=        src,
                reading_count= cnt,
            ))
            real_days += 1

    return VhsTrendMeta(
        equipment_id=   equipment_id,
        days=           days,
        real_days=      real_days,
        estimated_days= days - real_days,
        data=           data,
    )


@router.post("/readings", response_model=VhsReadingOut, status_code=201)
async def create_vhs_reading(
    payload: VhsReadingCreate,
    db:      AsyncSession = Depends(get_db),
):
    """
    寫入 VHS 評分（手動輸入 / VLM 推論結束後呼叫）。
    recorded_at 未填則使用 server time（UTC）。
    """
    reading = VhsReading(
        id=           str(uuid.uuid4()),
        equipment_id= payload.equipment_id,
        score=        payload.score,
        source=       payload.source,
        notes=        payload.notes,
        recorded_at=  payload.recorded_at or datetime.now(timezone.utc),
        created_at=   datetime.now(timezone.utc),
    )
    db.add(reading)
    await db.commit()
    await db.refresh(reading)
    return reading
