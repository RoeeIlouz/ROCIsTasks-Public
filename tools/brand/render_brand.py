"""Contact sheet + PNG exports for assets/brand/svg (Playwright, transparent backgrounds)."""
import os
import sys
from playwright.sync_api import sync_playwright

BRAND = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'brand'))
SVG = os.path.join(BRAND, 'svg')
PNG = os.path.join(BRAND, 'png')
SHOTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
os.makedirs(SHOTS, exist_ok=True)
url = lambda name: 'file:///' + os.path.join(SVG, name).replace('\\', '/')

# (svg, png name, width, height)
EXPORTS = []
for app in ('tasks', 'schedule'):
    EXPORTS += [
        (f'{app}-icon.svg', f'{app}-icon-1024.png', 1024, 1024),
        (f'{app}-icon-square.svg', f'{app}-play-store-512.png', 512, 512),
        (f'{app}-icon-square.svg', f'{app}-web-maskable-512.png', 512, 512),
        (f'{app}-icon-square.svg', f'{app}-web-maskable-192.png', 192, 192),
        (f'{app}-icon.svg', f'{app}-web-512.png', 512, 512),
        (f'{app}-icon.svg', f'{app}-web-192.png', 192, 192),
        (f'{app}-icon-square.svg', f'{app}-apple-touch-180.png', 180, 180),
        (f'{app}-icon.svg', f'{app}-favicon-32.png', 32, 32),
        (f'{app}-adaptive-foreground.svg', f'{app}-adaptive-foreground-1024.png', 1024, 1024),
        (f'{app}-adaptive-background.svg', f'{app}-adaptive-background-1024.png', 1024, 1024),
        (f'{app}-adaptive-monochrome.svg', f'{app}-adaptive-monochrome-1024.png', 1024, 1024),
    ]
EXPORTS += [
    ('studio-icon.svg', 'studio-icon-1024.png', 1024, 1024),
    ('studio-icon.svg', 'studio-icon-512.png', 512, 512),
    ('studio-icon.svg', 'studio-icon-192.png', 192, 192),
    ('studio-icon-square.svg', 'studio-apple-touch-180.png', 180, 180),
    ('studio-icon.svg', 'studio-favicon-32.png', 32, 32),
    ('studio-icon.svg', 'studio-favicon-16.png', 16, 16),
    ('lockup-rocis-apps-light.svg', 'lockup-rocis-apps-light.png', 2400, 0),
    ('lockup-rocis-apps-dark.svg', 'lockup-rocis-apps-dark.png', 2400, 0),
    ('wordmark-rocis-apps-light.svg', 'wordmark-rocis-apps-light.png', 2000, 0),
    ('wordmark-rocis-apps-dark.svg', 'wordmark-rocis-apps-dark.png', 2000, 0),
]

SHEET = """<body style="margin:0;padding:24px;font:13px sans-serif;display:grid;gap:18px">
<div style="display:flex;gap:16px;align-items:flex-end;background:#f5f5f4;padding:16px">%(icons)s</div>
<div style="display:flex;gap:16px;align-items:flex-end;background:#17181b;padding:16px">%(icons)s</div>
<div style="display:flex;gap:16px;align-items:flex-end;background:#f5f5f4;padding:16px">%(adaptive)s</div>
<div style="background:#f5f5f4;padding:16px;display:grid;gap:12px"><img src="%(lockL)s" style="height:70px"><img src="%(wmL)s" style="height:52px"></div>
<div style="background:#17181b;padding:16px;display:grid;gap:12px"><img src="%(lockD)s" style="height:70px"><img src="%(wmD)s" style="height:52px"></div>
</body>"""


def sheet():
    icons = ''.join(f'<img src="{url(n)}" width="{s}" height="{s}">' for n in ('studio-icon.svg', 'tasks-icon.svg', 'schedule-icon.svg') for s in (120, 48))
    adaptive = ''
    for app in ('tasks', 'schedule'):
        # Circle mask (the strictest launcher shape) over background + foreground, then the monochrome layer.
        adaptive += (f'<div style="position:relative;width:162px;height:162px;border-radius:50%;overflow:hidden">'
                     f'<img src="{url(app + "-adaptive-background.svg")}" style="position:absolute;inset:-27px;width:216px">'
                     f'<img src="{url(app + "-adaptive-foreground.svg")}" style="position:absolute;inset:-27px;width:216px"></div>'
                     f'<div style="position:relative;width:162px;height:162px;border-radius:50%;overflow:hidden;background:#3b5b43">'
                     f'<img src="{url(app + "-adaptive-monochrome.svg")}" style="position:absolute;inset:-27px;width:216px"></div>')
    return SHEET % {'icons': icons, 'adaptive': adaptive,
                    'lockL': url('lockup-rocis-apps-light.svg'), 'wmL': url('wordmark-rocis-apps-light.svg'),
                    'lockD': url('lockup-rocis-apps-dark.svg'), 'wmD': url('wordmark-rocis-apps-dark.svg')}


with sync_playwright() as p:
    b = p.chromium.launch()
    if 'sheet' in sys.argv:
        pg = b.new_page(viewport={'width': 1100, 'height': 900})
        path = os.path.join(SHOTS, 'brand_sheet.html')
        open(path, 'w', encoding='utf-8').write(sheet())
        pg.goto('file:///' + path.replace('\\', '/'))
        pg.wait_for_timeout(800)
        pg.screenshot(path=os.path.join(SHOTS, 'brand_sheet.png'), full_page=True)
        print('sheet done')
    if 'export' in sys.argv:
        os.makedirs(PNG, exist_ok=True)
        for svg, name, w, h in EXPORTS:
            pg = b.new_page(viewport={'width': w, 'height': h or w})
            pg.set_content(f'<body style="margin:0;background:transparent"><img id="i" src="{url(svg)}" style="display:block;width:{w}px"></body>')
            pg.wait_for_function('document.getElementById("i").complete')
            img = pg.query_selector('#i')
            img.screenshot(path=os.path.join(PNG, name), omit_background=True)
            pg.close()
        print(len(EXPORTS), 'PNGs ->', PNG)
    b.close()

