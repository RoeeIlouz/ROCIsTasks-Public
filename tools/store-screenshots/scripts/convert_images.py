"""Convert PNG exports with Chromium's canvas encoder (no Pillow needed).

usage: python convert_images.py <jpeg|webp> <quality 0-1> <width|0 keeps size> <src> <dst> [<src> <dst> ...]
JPEG output is flattened on white, so it has no alpha (Play requirement).
"""
import base64
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

fmt, quality, width = sys.argv[1], float(sys.argv[2]), int(sys.argv[3])
pairs = list(zip(sys.argv[4::2], sys.argv[5::2]))

JS = """async ([src, mime, q, w]) => {
  const img = new Image(); img.src = src; await img.decode();
  const W = w || img.naturalWidth, H = Math.round(img.naturalHeight * W / img.naturalWidth);
  const c = document.createElement('canvas'); c.width = W; c.height = H;
  const x = c.getContext('2d'); x.imageSmoothingQuality = 'high';
  if (mime === 'image/jpeg') { x.fillStyle = '#fff'; x.fillRect(0, 0, W, H); }
  x.drawImage(img, 0, 0, W, H);
  return c.toDataURL(mime, q);
}"""

with sync_playwright() as p:
    page = p.chromium.launch().new_page()
    for src, dst in pairs:
        data = "data:image/png;base64," + base64.b64encode(Path(src).read_bytes()).decode()
        url = page.evaluate(JS, [data, f"image/{fmt}", quality, width])
        Path(dst).parent.mkdir(parents=True, exist_ok=True)
        Path(dst).write_bytes(base64.b64decode(url.split(",", 1)[1]))
        print(dst)
