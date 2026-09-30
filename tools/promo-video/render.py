"""Render promo.html to MP4, frame by frame (deterministic, no screen recording).

usage: python render.py <tasks|schedule> <16x9|9x16> <out.mp4> [--fps 30] [--still SECONDS]
Needs Playwright + Chromium and ffmpeg on PATH. Screens come from assets/<app>/ (see README.md).
--still writes a single PNG at that time instead of a video (for review).
"""
import argparse
import subprocess
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent

ap = argparse.ArgumentParser()
ap.add_argument("app")
ap.add_argument("fmt")
ap.add_argument("out")
ap.add_argument("--fps", type=int, default=30)
ap.add_argument("--still", type=float)
args = ap.parse_args()
w, h = (1080, 1920) if args.fmt == "9x16" else (1920, 1080)

with sync_playwright() as p:
    browser = p.chromium.launch(args=["--allow-file-access-from-files"])
    page = browser.new_page(viewport={"width": w, "height": h})
    page.goto(f"{(HERE / 'promo.html').as_uri()}?app={args.app}&fmt={args.fmt}")
    page.evaluate("window.ready")
    if args.still is not None:
        page.evaluate(f"window.seek({args.still})")
        page.screenshot(path=args.out)
    else:
        frames = int(page.evaluate("window.DURATION") * args.fps)
        ff = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(args.fps),
             "-vcodec", "png", "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "18",
             "-pix_fmt", "yuv420p", "-movflags", "+faststart", args.out],
            stdin=subprocess.PIPE)
        for f in range(frames):
            page.evaluate(f"window.seek({f / args.fps})")
            ff.stdin.write(page.screenshot(type="png"))
        ff.stdin.close()
        if ff.wait():
            raise SystemExit("ffmpeg failed")
        print(f"{args.out}: {frames} frames")
    browser.close()
