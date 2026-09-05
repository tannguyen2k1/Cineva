from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.schemas.common import ORMModel


class TaxonomyOut(ORMModel):
    slug: str
    name: str


class FilmCardOut(ORMModel):
    id: str
    slug: str
    name: str
    original_name: str | None = Field(default=None, alias="originalName")
    thumb_url: str | None = Field(default=None, alias="thumbUrl")
    poster_url: str | None = Field(default=None, alias="posterUrl")
    year: str | None = None
    quality: str | None = None
    language: str | None = None
    current_episode: str | None = Field(default=None, alias="currentEpisode")
    total_episodes: int | None = Field(default=None, alias="totalEpisodes")
    avg_rating: float = Field(default=0, alias="avgRating")
    rating_count: int = Field(default=0, alias="ratingCount")
    genres: list[TaxonomyOut] = []
    is_hidden: bool | None = Field(default=None, alias="isHidden")


class EpisodeItemOut(ORMModel):
    name: str
    slug: str
    embed: str


class EpisodeServerOut(ORMModel):
    server_name: str = Field(alias="serverName")
    items: list[EpisodeItemOut]


class FilmDetailOut(FilmCardOut):
    description: str | None = None
    time: str | None = None
    director: str | None = None
    casts: str | None = None
    countries: list[TaxonomyOut] = []
    types: list[TaxonomyOut] = []
    episodes: list[EpisodeServerOut] = []
    user_score: int | None = Field(default=None, alias="userScore")
    in_watchlist: bool | None = Field(default=None, alias="inWatchlist")
    is_following: bool | None = Field(default=None, alias="isFollowing")


class BannerOut(ORMModel):
    id: str
    title: str
    image_url: str = Field(alias="imageUrl")
    link_url: str | None = Field(default=None, alias="linkUrl")
    film_slug: str | None = Field(default=None, alias="filmSlug")
    sort_order: int = Field(alias="sortOrder")
    is_active: bool | None = Field(default=None, alias="isActive")


class BannerCreate(ORMModel):
    title: str
    image_url: str = Field(alias="imageUrl")
    link_url: str | None = Field(default=None, alias="linkUrl")
    film_slug: str | None = Field(default=None, alias="filmSlug")
    sort_order: int = Field(default=0, alias="sortOrder")
    is_active: bool = Field(default=True, alias="isActive")
    starts_at: datetime | None = Field(default=None, alias="startsAt")
    ends_at: datetime | None = Field(default=None, alias="endsAt")


class BannerUpdate(ORMModel):
    title: str | None = None
    image_url: str | None = Field(default=None, alias="imageUrl")
    link_url: str | None = Field(default=None, alias="linkUrl")
    film_slug: str | None = Field(default=None, alias="filmSlug")
    sort_order: int | None = Field(default=None, alias="sortOrder")
    is_active: bool | None = Field(default=None, alias="isActive")
    starts_at: datetime | None = Field(default=None, alias="startsAt")
    ends_at: datetime | None = Field(default=None, alias="endsAt")


class FeaturedCreate(ORMModel):
    film_slug: str = Field(alias="filmSlug")
    section: str = "home_hot"
    sort_order: int = Field(default=0, alias="sortOrder")


class FeaturedOut(ORMModel):
    id: str
    section: str
    sort_order: int = Field(alias="sortOrder")
    film: FilmCardOut


class ProgressUpdate(ORMModel):
    slug: str
    episode_slug: str = Field(alias="episodeSlug")
    episode_name: str | None = Field(default=None, alias="episodeName")
    server_name: str | None = Field(default=None, alias="serverName")
    position_sec: int | None = Field(default=None, alias="positionSec")


class ProgressOut(ORMModel):
    slug: str
    episode_slug: str = Field(alias="episodeSlug")
    episode_name: str | None = Field(default=None, alias="episodeName")
    server_name: str | None = Field(default=None, alias="serverName")
    position_sec: int | None = Field(default=None, alias="positionSec")
    updated_at: datetime = Field(alias="updatedAt")
    film: FilmCardOut | None = None


class RatingUpdate(ORMModel):
    score: int = Field(ge=1, le=10)


class CommentCreate(ORMModel):
    body: str = Field(min_length=1, max_length=2000)
    parent_id: str | None = Field(default=None, alias="parentId")


class CommentOut(ORMModel):
    id: str
    body: str
    username: str
    created_at: datetime = Field(alias="createdAt")
    is_hidden: bool | None = Field(default=None, alias="isHidden")
    film_slug: str | None = Field(default=None, alias="filmSlug")
    film_name: str | None = Field(default=None, alias="filmName")
    parent_id: str | None = Field(default=None, alias="parentId")
    replies: list["CommentOut"] | None = None


class FilmHideUpdate(ORMModel):
    is_hidden: bool = Field(alias="isHidden")


class RegisterRequest(ORMModel):
    username: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=6, max_length=128)
    email: str | None = None
    full_name: str | None = Field(default=None, alias="fullName")
    turnstile_token: str = Field(alias="turnstileToken")


class SyncRunOut(ORMModel):
    id: str
    job_type: str = Field(alias="jobType")
    status: str
    page_from: int | None = Field(default=None, alias="pageFrom")
    page_to: int | None = Field(default=None, alias="pageTo")
    items_upserted: int = Field(alias="itemsUpserted")
    error: str | None = None
    started_at: datetime = Field(alias="startedAt")
    finished_at: datetime | None = Field(default=None, alias="finishedAt")
