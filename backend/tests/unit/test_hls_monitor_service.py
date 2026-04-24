from __future__ import annotations

import pytest
from sqlalchemy import select

from models.db_models import EquipmentAlert
from services.hls_monitor_service import (
    HLS_ALERT_EQUIPMENT_ID,
    create_hls_alert_if_needed,
    resolve_hls_alerts,
)


@pytest.mark.anyio
async def test_hls_failures_create_single_unresolved_alert(db_session):
    created1 = await create_hls_alert_if_needed(db_session, "fail #1")
    created2 = await create_hls_alert_if_needed(db_session, "fail #2")

    assert created1 is True
    assert created2 is False

    rows = (
        await db_session.execute(
            select(EquipmentAlert).where(
                EquipmentAlert.equipment_id == HLS_ALERT_EQUIPMENT_ID
            )
        )
    ).scalars().all()
    assert len(rows) == 1
    assert rows[0].resolved is False
    assert rows[0].level == "critical"


@pytest.mark.anyio
async def test_hls_recovery_resolves_existing_alert(db_session):
    await create_hls_alert_if_needed(db_session, "stream down")

    resolved_count = await resolve_hls_alerts(db_session)
    assert resolved_count == 1

    rows = (
        await db_session.execute(
            select(EquipmentAlert).where(
                EquipmentAlert.equipment_id == HLS_ALERT_EQUIPMENT_ID
            )
        )
    ).scalars().all()
    assert len(rows) == 1
    assert rows[0].resolved is True
    assert rows[0].resolved_at is not None
