from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime, timezone

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import AsyncSessionLocal
from models.db_models import EquipmentAlert

logger = logging.getLogger(__name__)
settings = get_settings()

HLS_ALERT_EQUIPMENT_ID = "d435i-hls"
HLS_ALERT_EQUIPMENT_NAME = "D435i HLS Stream"


async def fetch_hls_ok(url: str, timeout_sec: int) -> bool:
    try:
        timeout = httpx.Timeout(timeout_sec)
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.get(url)
        if response.status_code < 200 or response.status_code >= 300:
            return False
        return "#EXTM3U" in response.text
    except Exception:
        return False


async def get_unresolved_hls_alerts(db: AsyncSession) -> list[EquipmentAlert]:
    result = await db.execute(
        select(EquipmentAlert).where(
            EquipmentAlert.equipment_id == HLS_ALERT_EQUIPMENT_ID,
            EquipmentAlert.resolved == False,  # noqa: E712
        )
    )
    return list(result.scalars().all())


async def create_hls_alert_if_needed(db: AsyncSession, message: str) -> bool:
    unresolved = await get_unresolved_hls_alerts(db)
    if unresolved:
        return False

    alert = EquipmentAlert(
        id=str(uuid.uuid4()),
        equipment_id=HLS_ALERT_EQUIPMENT_ID,
        equipment_name=HLS_ALERT_EQUIPMENT_NAME,
        level="critical",
        message=message,
        resolved=False,
        created_at=datetime.now(timezone.utc),
    )
    db.add(alert)
    await db.commit()
    return True


async def resolve_hls_alerts(db: AsyncSession) -> int:
    unresolved = await get_unresolved_hls_alerts(db)
    if not unresolved:
        return 0

    now = datetime.now(timezone.utc)
    for alert in unresolved:
        alert.resolved = True
        alert.resolved_at = now
    await db.commit()
    return len(unresolved)


async def hls_monitor_loop() -> None:
    failure_count = 0
    url = settings.hls_monitor_url
    interval = max(1, settings.hls_monitor_interval_sec)
    timeout = max(1, settings.hls_monitor_timeout_sec)
    threshold = max(1, settings.hls_monitor_failure_threshold)

    logger.info(
        "HLS monitor started: url=%s interval=%ss timeout=%ss threshold=%s",
        url, interval, timeout, threshold,
    )

    while True:
        ok = await fetch_hls_ok(url, timeout)

        if ok:
            failure_count = 0
            async with AsyncSessionLocal() as db:
                resolved = await resolve_hls_alerts(db)
                if resolved > 0:
                    logger.info("HLS recovered, resolved %d alert(s)", resolved)
        else:
            failure_count += 1
            logger.warning("HLS check failed (%d/%d): %s", failure_count, threshold, url)
            if failure_count >= threshold:
                message = (
                    f"D435i HLS stream unavailable "
                    f"(url={url}, failures={failure_count}, threshold={threshold})"
                )
                async with AsyncSessionLocal() as db:
                    created = await create_hls_alert_if_needed(db, message)
                if created:
                    logger.error("HLS monitor created critical alert: %s", url)

        await asyncio.sleep(interval)
