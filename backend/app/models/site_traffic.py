from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base_fields import new_uuid


class SiteVisit(Base):
    """One page-view / session hit with client metadata."""

    __tablename__ = "site_visits"
    __table_args__ = (
        Index("ix_site_visits_created_at", "created_at"),
        Index("ix_site_visits_visitor_key", "visitor_key"),
        Index("ix_site_visits_path", "path"),
        Index("ix_site_visits_ip", "ip"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    path: Mapped[str] = mapped_column(String(512), nullable=False, default="/")
    method: Mapped[str] = mapped_column(String(16), nullable=False, default="GET")
    ip: Mapped[str | None] = mapped_column(String(64), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(Text, nullable=True)
    device_type: Mapped[str | None] = mapped_column(String(32), nullable=True)  # desktop|mobile|tablet|bot
    os_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    browser_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    referrer: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    language: Mapped[str | None] = mapped_column(String(64), nullable=True)
    visitor_key: Mapped[str] = mapped_column(String(64), nullable=False)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class SiteTrafficDaily(Base):
    __tablename__ = "site_traffic_daily"
    __table_args__ = (Index("ix_site_traffic_daily_day", "day"),)

    day: Mapped[date] = mapped_column(Date, primary_key=True)
    page_views: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    unique_visitors: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class SiteVisitorDay(Base):
    """One row per visitor fingerprint per calendar day (VN timezone)."""

    __tablename__ = "site_visitor_days"
    __table_args__ = (
        UniqueConstraint("day", "visitor_key", name="uq_site_visitor_day_key"),
        Index("ix_site_visitor_days_day", "day"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    day: Mapped[date] = mapped_column(Date, nullable=False)
    visitor_key: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
