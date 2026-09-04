from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.film import Film
    from app.models.user import User


class WatchProgress(Base):
    __tablename__ = "watch_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "film_id", name="uq_watch_progress_user_film"),
        Index("ix_watch_progress_user_id", "user_id"),
        Index("ix_watch_progress_updated_at", "updated_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    film_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("films.id", ondelete="CASCADE"), nullable=False
    )
    episode_slug: Mapped[str] = mapped_column(String(128), nullable=False)
    episode_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    server_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    position_sec: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    film: Mapped[Film] = relationship(back_populates="watch_progress_items")
    user: Mapped[User] = relationship()
