"""Render shorts.html (9:16 feature shorts over real emulator footage) to MP4.

usage: python render_shorts.py <1|2|3> <out.mp4> [--fps 30] [--still SECONDS]
Footage frames live in assets/shorts/<clip>/NNNN.jpg (30 fps), see README.md.
--still writes a single PNG at that time instead of a video (for review).
"""
import argparse
import subprocess
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent

ap = argparse.ArgumentParser()
ap.add_argument("short")
ap.add_argument("out")
ap.add_argument("--fps", type=int, default=30)
ap.add_argument("--still", type=float)
args = ap.parse_args()

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--allow-file-access-from-files"])
    page = browser.new_page(viewport={"width": 1080, "height": 1920})
    page.goto(f"{(HERE / 'shorts.html').as_uri()}?v={args.short}")
    page.evaluate("window.ready")
    if args.still is not None:
        page.evaluate(f"window.seek({args.still})")
        page.screenshot(path=args.out)
    else:
        frames = int(page.evaluate("window.DURATION") * args.fps)
        sfx = HERE / "assets" / "shorts" / f"sfx{args.short}.wav"  # from sfx.py
        audio = ["-i", str(sfx), "-c:a", "aac", "-b:a", "192k", "-t", str(frames / args.fps)] if sfx.exists() else []
        ff = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(args.fps),
             "-vcodec", "mjpeg", "-i", "-", *audio, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
             "-pix_fmt", "yuv420p", "-movflags", "+faststart", args.out],
            stdin=subprocess.PIPE)
        for f in range(frames):
            page.evaluate(f"window.seek({f / args.fps})")
            ff.stdin.write(page.screenshot(type="jpeg", quality=95))
        ff.stdin.close()
        if ff.wait():
            raise SystemExit("ffmpeg failed")
        print(f"{args.out}: {frames} frames")
    browser.close()
