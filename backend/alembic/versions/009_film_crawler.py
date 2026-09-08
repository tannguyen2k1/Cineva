"""Add local film images and resumable crawler progress.

Revision ID: 009_film_crawler
Revises: 008_site_traffic
Create Date: 2026-09-08
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "009_film_crawler"
down_revision: Union[str, None] = "008_site_traffic"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("films", sa.Column("local_thumb_url", sa.String(1024), nullable=True))
    op.add_column("films", sa.Column("local_poster_url", sa.String(1024), nullable=True))
    op.add_column(
        "films", sa.Column("thumb_source_fingerprint", sa.String(64), nullable=True)
    )
    op.add_column(
        "films", sa.Column("poster_source_fingerprint", sa.String(64), nullable=True)
    )
    op.add_column("films", sa.Column("images_synced_at", sa.DateTime(timezone=True)))
    op.add_column("films", sa.Column("images_error", sa.Text(), nullable=True))

    op.add_column(
        "sync_runs",
        sa.Column("checkpoint_page", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column("sync_runs", sa.Column("total_pages", sa.Integer(), nullable=True))
    for name in (
        "items_discovered",
        "items_inserted",
        "items_updated",
        "items_skipped",
        "items_failed",
        "images_downloaded",
        "images_failed",
    ):
        op.add_column(
            "sync_runs", sa.Column(name, sa.Integer(), nullable=False, server_default="0")
        )
    op.add_column("sync_runs", sa.Column("params_json", sa.Text(), nullable=True))
    op.add_column(
        "sync_runs", sa.Column("heartbeat_at", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("sync_runs", "heartbeat_at")
    op.drop_column("sync_runs", "params_json")
    for name in (
        "images_failed",
        "images_downloaded",
        "items_failed",
        "items_skipped",
        "items_updated",
        "items_inserted",
        "items_discovered",
    ):
        op.drop_column("sync_runs", name)
    op.drop_column("sync_runs", "total_pages")
    op.drop_column("sync_runs", "checkpoint_page")

    op.drop_column("films", "images_error")
    op.drop_column("films", "images_synced_at")
    op.drop_column("films", "poster_source_fingerprint")
    op.drop_column("films", "thumb_source_fingerprint")
    op.drop_column("films", "local_poster_url")
    op.drop_column("films", "local_thumb_url")
