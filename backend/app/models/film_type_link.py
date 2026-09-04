from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.film import Film
    from app.models.film_type import FilmType


class FilmTypeLink(Base):
    __tablename__ = "film_type_links"
    __table_args__ = (
        UniqueConstraint("film_id", "film_type_id", name="uq_film_type_link"),
        Index("ix_film_type_links_film_id", "film_id"),
        Index("ix_film_type_links_film_type_id", "film_type_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    film_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("films.id", ondelete="CASCADE"), nullable=False
    )
    film_type_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("film_types.id", ondelete="CASCADE"), nullable=False
    )

    film: Mapped[Film] = relationship(back_populates="type_links")
    film_type: Mapped[FilmType] = relationship(back_populates="film_links")
