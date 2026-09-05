from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base_fields import new_uuid

if TYPE_CHECKING:
    from app.models.film import Film
    from app.models.user import User


class FilmComment(Base):
    __tablename__ = "film_comments"
    __table_args__ = (
        Index("ix_film_comments_film_id", "film_id"),
        Index("ix_film_comments_user_id", "user_id"),
        Index("ix_film_comments_parent_id", "parent_id"),
        Index("ix_film_comments_deleted_at", "deleted_at"),
        Index("ix_film_comments_is_hidden", "is_hidden"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    film_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("films.id", ondelete="CASCADE"), nullable=False
    )
    parent_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("film_comments.id", ondelete="CASCADE"), nullable=True
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    film: Mapped[Film] = relationship(back_populates="comments")
    user: Mapped[User] = relationship()
    parent: Mapped[FilmComment | None] = relationship(
        remote_side="FilmComment.id", back_populates="replies"
    )
    replies: Mapped[list[FilmComment]] = relationship(
        back_populates="parent", cascade="all, delete-orphan"
    )
