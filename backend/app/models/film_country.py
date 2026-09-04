from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.country import Country
    from app.models.film import Film


class FilmCountry(Base):
    __tablename__ = "film_countries"
    __table_args__ = (
        UniqueConstraint("film_id", "country_id", name="uq_film_country"),
        Index("ix_film_countries_film_id", "film_id"),
        Index("ix_film_countries_country_id", "country_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    film_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("films.id", ondelete="CASCADE"), nullable=False
    )
    country_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("countries.id", ondelete="CASCADE"), nullable=False
    )

    film: Mapped[Film] = relationship(back_populates="countries")
    country: Mapped[Country] = relationship(back_populates="film_links")
