"""Render YouTube channel assets (avatar, banner, video thumbnails) into out/youtube/.

usage: python youtube_assets.py   (needs Playwright + Chromium; reads assets/brand/svg and assets/<app>/)
"""
from pathlib import Path
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
BRAND = HERE.parent.parent / "assets" / "brand" / "svg"
OUT = HERE / "out" / "youtube"
OUT.mkdir(parents=True, exist_ok=True)
uri = lambda p: Path(p).resolve().as_uri()
FONT = "<link href='https://fonts.googleapis.com/css2?family=Outfit:wght@500;800&display=block' rel='stylesheet'>"
BASE = "<style>*{margin:0;box-sizing:border-box}body{font-family:Outfit,sans-serif;color:#fff;overflow:hidden}</style>"

PAGES = {
    # Avatar: shown as a circle, so keep the mark inside the inscribed circle.
    "avatar-800.png": (800, 800, f"""<body style='width:800px;height:800px;background:#2E2F33;display:grid;place-items:center'>
      <img src='{uri(BRAND / "studio-icon.svg")}' style='width:520px'></body>"""),
    # Banner: 2560x1440; everything important inside the 1546x423 centre safe area (all devices).
    "banner-2560x1440.png": (2560, 1440, f"""<body style='width:2560px;height:1440px;background:radial-gradient(900px 600px at 30% 45%,#E5323F22,transparent),
      radial-gradient(900px 600px at 72% 55%,#0E6FA822,transparent),#1C1D21;display:grid;place-items:center'>
      <div style='width:1546px;height:423px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:28px'>
        <img src='{uri(BRAND / "lockup-rocis-apps-dark.svg")}' style='height:150px'>
        <div style='font-size:46px;font-weight:500;color:#A1A1AA'>Calm, focused apps for tasks and school</div></div></body>"""),
}
for app, name, line in (("tasks", "ROCIs Tasks", "Tasks & calendar on your home screen"),
                        ("schedule", "ROCIs Schedule", "Timetable, exams and GPA in one app")):
    bg = "#E5323F" if app == "tasks" else "#0E6FA8"
    PAGES[f"thumb-{app}-1280x720.png"] = (1280, 720, f"""<body style='width:1280px;height:720px;background:radial-gradient(700px 500px at 75% 40%,{bg}66,transparent),#0d0e11;position:relative'>
      <img src='{uri(HERE / "assets" / app / "icon.png")}' style='position:absolute;left:80px;top:150px;width:150px;border-radius:22%'>
      <div style='position:absolute;left:80px;top:330px;width:620px'>
        <div style='font-size:84px;font-weight:800;line-height:1'>{name}</div>
        <div style='font-size:38px;font-weight:500;color:#d4d4d8;margin-top:22px;line-height:1.2'>{line}</div></div>
      <img src='{uri(HERE / "assets" / app / "home.png")}' style='position:absolute;right:110px;top:60px;height:640px;border-radius:36px;border:8px solid #0c0d10;box-shadow:0 30px 80px #000a'></body>""")

with sync_playwright() as p:
    b = p.chromium.launch(args=["--allow-file-access-from-files"])
    for name, (w, h, html) in PAGES.items():
        pg = b.new_page(viewport={"width": w, "height": h})
        page_file = OUT / "_page.html"  # a file:// page may load local images; set_content's about:blank may not
        page_file.write_text(f"<!doctype html><html><head><meta charset='utf-8'>{FONT}{BASE}</head>{html}</html>", encoding="utf-8")
        pg.goto(page_file.as_uri(), wait_until="networkidle")
        pg.evaluate("document.fonts.ready")
        pg.screenshot(path=str(OUT / name))
        pg.close()
        print(name)
    b.close()
(OUT / "_page.html").unlink(missing_ok=True)
