import os
import mimetypes
import logging
from pathlib import Path
from typing import Optional, Tuple, List

logger = logging.getLogger(__name__)

REPO_OWNER = "RoeeIlouz"
REPO_NAME = "ROCIs-Tasks"
BRANCH = "main"
GITHUB_RAW_BASE = f"https://raw.githubusercontent.com/{REPO_OWNER}/{REPO_NAME}/{BRANCH}"

DEFAULT_BANNER_PATH = "assets/images/play_store/feature_graphic.png"
DEFAULT_LOGO_PATH = "assets/images/logo.png"

class MediaManager:
    """
    Manages promotional image assets, screenshots, and public CDN links
    for cross-platform distribution.
    """
    def __init__(self, root_dir: Optional[Path] = None):
        if root_dir:
            self.root_dir = Path(root_dir)
        else:
            # Default to workspace root (2 levels up from scripts/marketing_bot)
            self.root_dir = Path(__file__).resolve().parent.parent.parent

    def get_cdn_url(self, relative_path: str) -> str:
        """Returns the public GitHub Raw CDN URL for an asset path."""
        norm_path = relative_path.replace("\\", "/").lstrip("/")
        return f"{GITHUB_RAW_BASE}/{norm_path}"

    def get_default_banner_url(self) -> str:
        """Returns public URL for the primary feature banner."""
        return self.get_cdn_url(DEFAULT_BANNER_PATH)

    def get_logo_url(self) -> str:
        """Returns public URL for the app emblem/logo."""
        return self.get_cdn_url(DEFAULT_LOGO_PATH)

    def get_asset_file(self, relative_path: str) -> Optional[Path]:
        """Resolves an asset file path safely on local disk."""
        target = self.root_dir / relative_path
        if target.is_file():
            return target
        return None

    def get_asset_data(self, relative_path: str) -> Optional[Tuple[bytes, str]]:
        """
        Reads local image asset and detects its MIME type.
        Returns (bytes, mime_type) or None if file not found.
        """
        file_path = self.get_asset_file(relative_path)
        if not file_path:
            logger.warning(f"Asset file not found: {relative_path}")
            return None

        try:
            with open(file_path, "rb") as f:
                data = f.read()
            mime, _ = mimetypes.guess_type(str(file_path))
            return data, mime or "image/png"
        except Exception as e:
            logger.error(f"Error reading asset {relative_path}: {e}")
            return None

    def get_default_banner_data(self) -> Optional[Tuple[bytes, str]]:
        """Returns (bytes, mime_type) for the primary feature graphic."""
        return self.get_asset_data(DEFAULT_BANNER_PATH)

    def list_available_screenshots(self) -> List[str]:
        """Lists relative paths of available screenshots."""
        screenshots_dir = self.root_dir / "assets" / "images" / "play_store"
        if not screenshots_dir.is_dir():
            return []
        shots = sorted([
            f"assets/images/play_store/{p.name}"
            for p in screenshots_dir.glob("screenshot_*.png")
        ])
        return shots

