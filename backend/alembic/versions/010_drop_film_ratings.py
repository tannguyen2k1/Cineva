"""Drop user film ratings; scores come from KKPhim (IMDb/TMDB).

Revision ID: 010_drop_film_ratings
Revises: 009_film_crawler
Create Date: 2026-09-18
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "010_drop_film_ratings"
down_revision: Union[str, None] = "009_film_crawler"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_index("ix_film_ratings_film_id", table_name="film_ratings")
    op.drop_table("film_ratings")


def downgrade() -> None:
    op.create_table(
        "film_ratings",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("film_id", sa.String(length=36), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["film_id"], ["films.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "film_id", name="uq_film_rating_user_film"),
    )
    op.create_index("ix_film_ratings_film_id", "film_ratings", ["film_id"])
