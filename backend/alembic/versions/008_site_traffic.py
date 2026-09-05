"""Site traffic: detailed visits + daily aggregates.

Revision ID: 008_site_traffic
Revises: 007_film_follows
Create Date: 2026-09-05
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "008_site_traffic"
down_revision: Union[str, None] = "007_film_follows"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "site_visits",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("path", sa.String(512), nullable=False, server_default="/"),
        sa.Column("method", sa.String(16), nullable=False, server_default="GET"),
        sa.Column("ip", sa.String(64), nullable=True),
        sa.Column("user_agent", sa.Text(), nullable=True),
        sa.Column("device_type", sa.String(32), nullable=True),
        sa.Column("os_name", sa.String(64), nullable=True),
        sa.Column("browser_name", sa.String(64), nullable=True),
        sa.Column("referrer", sa.String(1024), nullable=True),
        sa.Column("language", sa.String(64), nullable=True),
        sa.Column("visitor_key", sa.String(64), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_site_visits_created_at", "site_visits", ["created_at"])
    op.create_index("ix_site_visits_visitor_key", "site_visits", ["visitor_key"])
    op.create_index("ix_site_visits_path", "site_visits", ["path"])
    op.create_index("ix_site_visits_ip", "site_visits", ["ip"])

    op.create_table(
        "site_traffic_daily",
        sa.Column("day", sa.Date(), primary_key=True),
        sa.Column("page_views", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("unique_visitors", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_site_traffic_daily_day", "site_traffic_daily", ["day"])

    op.create_table(
        "site_visitor_days",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("visitor_key", sa.String(64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("day", "visitor_key", name="uq_site_visitor_day_key"),
    )
    op.create_index("ix_site_visitor_days_day", "site_visitor_days", ["day"])


def downgrade() -> None:
    op.drop_table("site_visitor_days")
    op.drop_table("site_traffic_daily")
    op.drop_table("site_visits")
