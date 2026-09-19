from __future__ import annotations

import html
import re

_BLOCK_BREAK_RE = re.compile(
    r"</(?:p|div|h[1-6]|li|tr)\s*>\s*<(?:p|div|h[1-6]|li|tr)[^>]*>",
    re.IGNORECASE,
)
_BR_RE = re.compile(r"<br\s*/?>", re.IGNORECASE)
_TAG_RE = re.compile(r"<[^>]+>", re.DOTALL)
_SPACE_RE = re.compile(r"[ \t]{2,}")
_BLANK_RE = re.compile(r"\n{3,}")


def strip_html(value: str | None) -> str | None:
    """Remove HTML tags from film blurbs; keep plain text for mobile/API clients."""
    if value is None:
        return None
    text = value.strip()
    if not text:
        return None
    text = _BLOCK_BREAK_RE.sub("\n\n", text)
    text = _BR_RE.sub("\n", text)
    text = _TAG_RE.sub("", text)
    text = html.unescape(text)
    text = _SPACE_RE.sub(" ", text)
    text = _BLANK_RE.sub("\n\n", text)
    text = text.strip()
    return text or None
