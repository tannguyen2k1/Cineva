from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.film_type_link import FilmTypeLink


class FilmType(Base):
    """Định dạng: phim-bo, phim-le, dang-chieu, …"""

    __tablename__ = "film_types"
    __table_args__ = (Index("ix_film_types_slug", "slug", unique=True),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    slug: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    film_links: Mapped[list[FilmTypeLink]] = relationship(
        back_populates="film_type", cascade="all, delete-orphan"
    )
