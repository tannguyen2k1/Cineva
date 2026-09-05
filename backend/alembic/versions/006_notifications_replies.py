"""Notifications + comment replies.

Revision ID: 006_notifications_replies
Revises: 005_cineva_films
Create Date: 2026-09-05
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "006_notifications_replies"
down_revision: Union[str, None] = "005_cineva_films"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "film_comments",
        sa.Column("parent_id", sa.String(36), sa.ForeignKey("film_comments.id", ondelete="CASCADE"), nullable=True),
    )
    op.create_index("ix_film_comments_parent_id", "film_comments", ["parent_id"])

    op.create_table(
        "notifications",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=True),
        sa.Column("comment_id", sa.String(36), sa.ForeignKey("film_comments.id", ondelete="SET NULL"), nullable=True),
        sa.Column("kind", sa.String(32), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("link_url", sa.String(512), nullable=True),
        sa.Column("ref_key", sa.String(255), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "kind", "ref_key", name="uq_notification_user_kind_ref"),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_is_read", "notifications", ["is_read"])
    op.create_index("ix_notifications_created_at", "notifications", ["created_at"])


def downgrade() -> None:
    op.drop_table("notifications")
    op.drop_index("ix_film_comments_parent_id", table_name="film_comments")
    op.drop_column("film_comments", "parent_id")
