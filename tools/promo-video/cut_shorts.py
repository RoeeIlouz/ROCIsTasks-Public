"""Cut the raw emulator takes into the footage sequences shorts.html plays.

usage: python cut_shorts.py <raw_dir>
<raw_dir> holds d1_cfr.mp4, d2_cfr.mp4, d3_cfr.mp4: `adb shell screenrecord` takes converted to constant
30 fps (`ffmpeg -i d1.mp4 -vf fps=30 d1_cfr.mp4`). Each short is a list of (first_frame, end_frame, speed)
segments of its take; the result is assets/shorts/<n>/NNNN.jpg at 30 fps plus a keys.json of frame indices
where the typed text changes (short 1), which sfx.py turns into key clicks.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent

CUTS = {
    1: [(45, 150, 1.6), (150, 362, 2.2), (362, 418, 1.0), (418, 505, 1.0)],
    2: [(45, 132, 1.0), (205, 290, 1.0), (290, 330, 1.0)],
    3: [(75, 185, 1.0), (240, 350, 1.25), (425, 470, 1.0), (470, 560, 1.0)],
}


def main(raw: Path) -> None:
    for n, segs in CUTS.items():
        out = HERE / "assets" / "shorts" / str(n)
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(raw / f"d{n}_cfr.mp4"), "-q:v", "2",
                            str(Path(tmp) / "%04d.jpg")], check=True)
            src = []
            for a, b, speed in segs:
                src += [a + round(k * speed) for k in range(int((b - a) / speed))]
            for i, f in enumerate(src):
                shutil.copy(Path(tmp) / f"{f + 1:04d}.jpg", out / f"{i:04d}.jpg")
            if n == 1:
                (out / "keys.json").write_text(json.dumps(typed_frames(Path(tmp), src)))
        print(f"short {n}: {len(src)} frames ({len(src) / 30:.2f}s)")


def typed_frames(tmp: Path, src: list[int]) -> list[int]:
    """Output frame indices where the quick-add text field changes, i.e. a key landed."""
    from PIL import Image, ImageChops, ImageStat
    box = (40, 1225, 1040, 1305)  # the text field line on a 1080x2400 capture
    keys, prev = [], None
    for i, f in enumerate(src):
        im = Image.open(tmp / f"{f + 1:04d}.jpg").convert("L").crop(box)
        if prev is not None and ImageStat.Stat(ImageChops.difference(im, prev)).mean[0] > 1.2:
            if not keys or i - keys[-1] > 1:
                keys.append(i)
        prev = im
    return keys


if __name__ == "__main__":
    main(Path(sys.argv[1]))
