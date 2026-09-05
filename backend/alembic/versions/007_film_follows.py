"""Film follows for episode notifications.

Revision ID: 007_film_follows
Revises: 006_notifications_replies
Create Date: 2026-09-05
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "007_film_follows"
down_revision: Union[str, None] = "006_notifications_replies"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "film_follows",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "film_id", name="uq_film_follow_user_film"),
    )
    op.create_index("ix_film_follows_user_id", "film_follows", ["user_id"])
    op.create_index("ix_film_follows_film_id", "film_follows", ["film_id"])


def downgrade() -> None:
    op.drop_table("film_follows")
