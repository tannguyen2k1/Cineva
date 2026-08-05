"""Add users.tokens_invalid_before for global access JWT invalidation.

Revision ID: 004_tokens_invalid_before
Revises: 003_revoked_access_tokens
Create Date: 2026-08-05
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "004_tokens_invalid_before"
down_revision: Union[str, None] = "003_revoked_access_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("tokens_invalid_before", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "tokens_invalid_before")
