from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, Float, Index, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.film_comment import FilmComment
    from app.models.film_country import FilmCountry
    from app.models.film_genre import FilmGenre
    from app.models.film_rating import FilmRating
    from app.models.film_type_link import FilmTypeLink
    from app.models.featured_film import FeaturedFilm
    from app.models.film_follow import FilmFollow
    from app.models.watch_progress import WatchProgress
    from app.models.watchlist_item import WatchlistItem


class Film(Base):
    __tablename__ = "films"
    __table_args__ = (
        Index("ix_films_source_slug", "source_slug", unique=True),
        Index("ix_films_name", "name"),
        Index("ix_films_year", "year"),
        Index("ix_films_is_hidden", "is_hidden"),
        Index("ix_films_source_modified_at", "source_modified_at"),
        Index("ix_films_synced_at", "synced_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    source_slug: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(512), nullable=False)
    original_name: Mapped[str | None] = mapped_column(String(512), nullable=True)
    thumb_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    poster_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    local_thumb_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    local_poster_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    thumb_source_fingerprint: Mapped[str | None] = mapped_column(String(64), nullable=True)
    poster_source_fingerprint: Mapped[str | None] = mapped_column(String(64), nullable=True)
    images_synced_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    images_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    year: Mapped[str | None] = mapped_column(String(16), nullable=True)
    quality: Mapped[str | None] = mapped_column(String(64), nullable=True)
    language: Mapped[str | None] = mapped_column(String(128), nullable=True)
    total_episodes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    current_episode: Mapped[str | None] = mapped_column(String(128), nullable=True)
    time: Mapped[str | None] = mapped_column(String(128), nullable=True)
    director: Mapped[str | None] = mapped_column(Text, nullable=True)
    casts: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    avg_rating: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    rating_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    source_modified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    genres: Mapped[list[FilmGenre]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    countries: Mapped[list[FilmCountry]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    type_links: Mapped[list[FilmTypeLink]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    featured_entries: Mapped[list[FeaturedFilm]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    watchlist_items: Mapped[list[WatchlistItem]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    follows: Mapped[list[FilmFollow]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    watch_progress_items: Mapped[list[WatchProgress]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    ratings: Mapped[list[FilmRating]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
    comments: Mapped[list[FilmComment]] = relationship(
        back_populates="film", cascade="all, delete-orphan"
    )
