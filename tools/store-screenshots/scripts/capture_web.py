"""Capture store screenshots from a Flutter web build at phone size.

usage: python capture_web.py <build_dir> <out_dir> <locale> <iso_time> <step> ...

Steps (run in order; the page loads first and waits for CanvasKit):
  c:X,Y     tap at CSS px (viewport 390x844)
  w:SECS    wait
  s:NAME    screenshot to <out_dir>/NAME.png (1170x2532)
  r         reload the page (e.g. after a first-run seed)
  t:TEXT    type text
  g:PATH    open base URL + PATH (e.g. #/share?d=...), then wait for load
Env STATUS_TIME=5:18 captures at 390x816 and adds a 28px Android status bar
(time, wifi, battery) tinted from the app's top edge, so web shots match emulator ones.
Env PREFS='{"language_code": "de"}' presets shared_preferences before first load.
Web can't show Android widgets or the camera; those come from emulator captures.
"""
import functools
import os
import http.server
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

from playwright.sync_api import sync_playwright

build, out, locale, iso = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
out.mkdir(parents=True, exist_ok=True)
status_time = os.environ.get("STATUS_TIME")
BAR = 28

COMPOSE = """<body style=margin:0><canvas id=c width=1170 height=2532></canvas><script>
const img = new Image(); img.onload = () => {
  const c = document.getElementById('c').getContext('2d');
  c.drawImage(img, 0, %(bar)d * 3);
  const [r, g, b] = c.getImageData(20, %(bar)d * 3 + 2, 1, 1).data;
  c.fillStyle = `rgb(${r},${g},${b})`; c.fillRect(0, 0, 1170, %(bar)d * 3);
  const fg = (r * 0.299 + g * 0.587 + b * 0.114) > 140 ? '#1f1f1f' : '#f5f5f5';
  c.fillStyle = fg; c.font = '500 42px Roboto, Arial, sans-serif'; c.textBaseline = 'middle';
  c.fillText('%(time)s', 72, 43);
  c.beginPath(); c.moveTo(1004, 60); c.arc(1004, 60, 40, -Math.PI * 0.75, -Math.PI * 0.25); c.closePath(); c.fill();
  c.fillRect(1052, 22, 26, 44); c.fillRect(1059, 16, 12, 8);
  document.title = 'done';
}; img.src = '%(src)s';</script>"""


def shoot(page, name):
    raw = out / f"{name}.png"
    page.screenshot(path=str(raw))
    if not status_time:
        return
    comp = page.context.browser.new_page(viewport={"width": 1170, "height": 2532})
    import base64
    src = "data:image/png;base64," + base64.b64encode(raw.read_bytes()).decode()
    comp.set_content(COMPOSE % {"bar": BAR, "time": status_time, "src": src})
    comp.wait_for_function("document.title === 'done'")
    comp.locator("canvas").screenshot(path=str(raw))
    comp.close()

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(build))
handler.log_message = lambda *a, **k: None
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()

with sync_playwright() as p:
    browser = p.chromium.launch()
    ctx = browser.new_context(viewport={"width": 390, "height": 844 - (BAR if status_time else 0)}, device_scale_factor=3,
                              is_mobile=True, has_touch=True, locale=locale)
    if os.environ.get("PREFS"):
        import json
        sets = "".join(f"localStorage.setItem('flutter.{k}', {json.dumps(json.dumps(v))});"
                       for k, v in json.loads(os.environ["PREFS"]).items())
        ctx.add_init_script(f"if (!sessionStorage.getItem('_seeded')) {{ {sets} sessionStorage.setItem('_seeded', '1'); }}")
    page = ctx.new_page()
    page.clock.set_fixed_time(datetime.fromisoformat(iso))
    base = f"http://127.0.0.1:{srv.server_address[1]}/"
    page.goto(base)
    time.sleep(10)
    for step in sys.argv[5:]:
        op, _, arg = step.partition(":")
        if op == "c":
            x, y = map(float, arg.split(","))
            page.touchscreen.tap(x, y)
            time.sleep(2)
        elif op == "w":
            time.sleep(float(arg))
        elif op == "s":
            shoot(page, arg)
            print("shot", arg)
        elif op == "r":
            page.reload()
            time.sleep(10)
        elif op == "g":
            page.goto(base + arg)
            time.sleep(10)
        elif op == "t":
            page.keyboard.type(arg)
    browser.close()
srv.shutdown()
