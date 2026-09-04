from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.film import Film
    from app.models.genre import Genre


class FilmGenre(Base):
    __tablename__ = "film_genres"
    __table_args__ = (
        UniqueConstraint("film_id", "genre_id", name="uq_film_genre"),
        Index("ix_film_genres_film_id", "film_id"),
        Index("ix_film_genres_genre_id", "genre_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    film_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("films.id", ondelete="CASCADE"), nullable=False
    )
    genre_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("genres.id", ondelete="CASCADE"), nullable=False
    )

    film: Mapped[Film] = relationship(back_populates="genres")
    genre: Mapped[Genre] = relationship(back_populates="film_links")
