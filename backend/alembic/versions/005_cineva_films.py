"""Cineva film catalog, engagement, and CMS tables.

Revision ID: 005_cineva_films
Revises: 004_tokens_invalid_before
Create Date: 2026-09-04
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "005_cineva_films"
down_revision: Union[str, None] = "004_tokens_invalid_before"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "genres",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("slug", sa.String(128), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_genres_slug", "genres", ["slug"], unique=True)

    op.create_table(
        "countries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("slug", sa.String(128), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_countries_slug", "countries", ["slug"], unique=True)

    op.create_table(
        "film_types",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("slug", sa.String(128), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_film_types_slug", "film_types", ["slug"], unique=True)

    op.create_table(
        "films",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("source_slug", sa.String(255), nullable=False),
        sa.Column("name", sa.String(512), nullable=False),
        sa.Column("original_name", sa.String(512), nullable=True),
        sa.Column("thumb_url", sa.String(1024), nullable=True),
        sa.Column("poster_url", sa.String(1024), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("year", sa.String(16), nullable=True),
        sa.Column("quality", sa.String(64), nullable=True),
        sa.Column("language", sa.String(128), nullable=True),
        sa.Column("total_episodes", sa.Integer(), nullable=True),
        sa.Column("current_episode", sa.String(128), nullable=True),
        sa.Column("time", sa.String(128), nullable=True),
        sa.Column("director", sa.Text(), nullable=True),
        sa.Column("casts", sa.Text(), nullable=True),
        sa.Column("is_hidden", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("avg_rating", sa.Float(), nullable=False, server_default=sa.text("0")),
        sa.Column("rating_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("source_modified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("synced_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_films_source_slug", "films", ["source_slug"], unique=True)
    op.create_index("ix_films_name", "films", ["name"])
    op.create_index("ix_films_year", "films", ["year"])
    op.create_index("ix_films_is_hidden", "films", ["is_hidden"])
    op.create_index("ix_films_source_modified_at", "films", ["source_modified_at"])
    op.create_index("ix_films_synced_at", "films", ["synced_at"])

    op.create_table(
        "film_genres",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("genre_id", sa.String(36), sa.ForeignKey("genres.id", ondelete="CASCADE"), nullable=False),
        sa.UniqueConstraint("film_id", "genre_id", name="uq_film_genre"),
    )
    op.create_index("ix_film_genres_film_id", "film_genres", ["film_id"])
    op.create_index("ix_film_genres_genre_id", "film_genres", ["genre_id"])

    op.create_table(
        "film_countries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("country_id", sa.String(36), sa.ForeignKey("countries.id", ondelete="CASCADE"), nullable=False),
        sa.UniqueConstraint("film_id", "country_id", name="uq_film_country"),
    )
    op.create_index("ix_film_countries_film_id", "film_countries", ["film_id"])
    op.create_index("ix_film_countries_country_id", "film_countries", ["country_id"])

    op.create_table(
        "film_type_links",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("film_type_id", sa.String(36), sa.ForeignKey("film_types.id", ondelete="CASCADE"), nullable=False),
        sa.UniqueConstraint("film_id", "film_type_id", name="uq_film_type_link"),
    )
    op.create_index("ix_film_type_links_film_id", "film_type_links", ["film_id"])
    op.create_index("ix_film_type_links_film_type_id", "film_type_links", ["film_type_id"])

    op.create_table(
        "banners",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("image_url", sa.String(1024), nullable=False),
        sa.Column("link_url", sa.String(1024), nullable=True),
        sa.Column("film_slug", sa.String(255), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_banners_is_active", "banners", ["is_active"])
    op.create_index("ix_banners_sort_order", "banners", ["sort_order"])

    op.create_table(
        "featured_films",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("section", sa.String(64), nullable=False, server_default="home_hot"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("film_id", "section", name="uq_featured_film_section"),
    )
    op.create_index("ix_featured_films_section", "featured_films", ["section"])
    op.create_index("ix_featured_films_sort_order", "featured_films", ["sort_order"])

    op.create_table(
        "watchlist_items",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "film_id", name="uq_watchlist_user_film"),
    )
    op.create_index("ix_watchlist_items_user_id", "watchlist_items", ["user_id"])
    op.create_index("ix_watchlist_items_film_id", "watchlist_items", ["film_id"])

    op.create_table(
        "watch_progress",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("episode_slug", sa.String(128), nullable=False),
        sa.Column("episode_name", sa.String(128), nullable=True),
        sa.Column("server_name", sa.String(128), nullable=True),
        sa.Column("position_sec", sa.Integer(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "film_id", name="uq_watch_progress_user_film"),
    )
    op.create_index("ix_watch_progress_user_id", "watch_progress", ["user_id"])
    op.create_index("ix_watch_progress_updated_at", "watch_progress", ["updated_at"])

    op.create_table(
        "film_ratings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "film_id", name="uq_film_rating_user_film"),
    )
    op.create_index("ix_film_ratings_film_id", "film_ratings", ["film_id"])

    op.create_table(
        "film_comments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("film_id", sa.String(36), sa.ForeignKey("films.id", ondelete="CASCADE"), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("is_hidden", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_film_comments_film_id", "film_comments", ["film_id"])
    op.create_index("ix_film_comments_user_id", "film_comments", ["user_id"])
    op.create_index("ix_film_comments_deleted_at", "film_comments", ["deleted_at"])
    op.create_index("ix_film_comments_is_hidden", "film_comments", ["is_hidden"])

    op.create_table(
        "sync_runs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("job_type", sa.String(64), nullable=False, server_default="incremental"),
        sa.Column("status", sa.String(32), nullable=False, server_default="running"),
        sa.Column("page_from", sa.Integer(), nullable=True),
        sa.Column("page_to", sa.Integer(), nullable=True),
        sa.Column("items_upserted", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_sync_runs_status", "sync_runs", ["status"])
    op.create_index("ix_sync_runs_created_at", "sync_runs", ["created_at"])


def downgrade() -> None:
    op.drop_table("sync_runs")
    op.drop_table("film_comments")
    op.drop_table("film_ratings")
    op.drop_table("watch_progress")
    op.drop_table("watchlist_items")
    op.drop_table("featured_films")
    op.drop_table("banners")
    op.drop_table("film_type_links")
    op.drop_table("film_countries")
    op.drop_table("film_genres")
    op.drop_table("films")
    op.drop_table("film_types")
    op.drop_table("countries")
    op.drop_table("genres")
