from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.film import Film


class FeaturedFilm(Base):
    __tablename__ = "featured_films"
    __table_args__ = (
        UniqueConstraint("film_id", "section", name="uq_featured_film_section"),
        Index("ix_featured_films_section", "section"),
        Index("ix_featured_films_sort_order", "sort_order"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    film_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("films.id", ondelete="CASCADE"), nullable=False
    )
    section: Mapped[str] = mapped_column(String(64), nullable=False, default="home_hot")
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    film: Mapped[Film] = relationship(back_populates="featured_entries")
