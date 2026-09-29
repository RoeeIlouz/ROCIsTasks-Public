"""Generate the ROCIs brand SVGs (outlined Unbounded, no font dependency).

Geometry mirrors the approved concept page (rocis-mark/r4.js + studio.js) on a
120-unit icon grid; Android adaptive layers use the 108dp grid with the 120
design mapped onto the visible 72dp centre (offset 18, scale 0.6).
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'assets', 'brand', 'svg')
os.makedirs(OUT, exist_ok=True)
G = json.load(open(os.path.join(HERE, 'unbounded_glyphs.json'), encoding='utf-8'))

RED, CHARCOAL, OCEAN, GREEN, WHITE = '#E5323F', '#2D2F33', '#0E6FA8', '#3CC44A', '#FFFFFF'
R = G['R700']
CAP = 750.0


def shade(hex_, f):
    n = int(hex_[1:], 16)
    return '#' + ''.join(f'{round(((n >> s) & 255) * f):02X}' for s in (16, 8, 0))


def r_letter(fill, cx, cy, h):
    """Unbounded R fitted to cap height h, centred on (cx, cy). Returns (svg, box)."""
    x0, y0, x1, y1 = R['bounds']
    s = h / CAP
    tx = cx - s * (x0 + x1) / 2
    ty = cy + s * (y0 + y1) / 2
    box = (cx - s * (x1 - x0) / 2, cy - s * (y1 - y0) / 2, s * (x1 - x0), s * (y1 - y0))
    return f'<path fill="{fill}" transform="translate({tx:.3f} {ty:.3f}) scale({s:.5f} {-s:.5f})" d="{R["d"]}"/>', box


def check_path(b):
    x, y, w, h = b
    return f'M{x + w * 0.56:.2f} {y + h * 0.8:.2f} L{x + w * 0.74:.2f} {y + h * 0.98:.2f} L{x + w * 1.1:.2f} {y + h * 0.55:.2f}'


def toe_trim(b):
    """Polygon under the check's long arm: trims the R's foot so no sliver shows past the check."""
    x, y, w, h = b
    pts = [(x + w * 0.74, y + h * 0.98), (x + w * 1.1, y + h * 0.55), (x + w * 1.25, y + h + 8), (x + w * 0.7, y + h + 8)]
    return 'M' + ' L'.join(f'{px:.2f} {py:.2f}' for px, py in pts) + ' Z'


def grid_cells(b):
    x0, y0, w, h = b
    s, c, g = 24, 8.5, 2.5
    x, y = x0 + w * 0.8 - 4, y0 + h - s + 4
    cells = [(x + 2.5 + i * (c + g), y + 2.5 + j * (c + g)) for j in (0, 1) for i in (0, 1)]
    return (x - 3, y - 3, s + 6), cells


def cue(app, band):
    if app == 'tasks':
        return (f'<rect x="43" y="12" width="34" height="18" rx="6" fill="{WHITE}"/>'
                f'<rect x="53" y="17" width="14" height="5" rx="2.5" fill="{band}"/>')
    return (f'<rect x="36" y="9" width="9" height="22" rx="4.5" fill="{WHITE}"/>'
            f'<rect x="75" y="9" width="9" height="22" rx="4.5" fill="{WHITE}"/>')


APPS = {'tasks': (CHARCOAL, RED), 'schedule': (OCEAN, GREEN)}


def app_content(app):
    """Cue + R + accent badge on the 120 grid (everything except tile and band)."""
    tile, accent = APPS[app]
    band = shade(tile, 0.78)
    letter, box = r_letter(WHITE, 58, 75, 58)
    if app == 'tasks':
        p = check_path(box)
        # Trim the R's foot under the check, then a knockout outline around it.
        badge = (f'<path d="{toe_trim(box)}" fill="{tile}"/>'
                 f'<path d="{p}" fill="none" stroke="{tile}" stroke-width="22" stroke-linejoin="round" stroke-linecap="round"/>'
                 f'<path d="{p}" fill="none" stroke="{accent}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round"/>')
    else:
        (bx, by, bs), cells = grid_cells(box)
        badge = f'<rect x="{bx:.2f}" y="{by:.2f}" width="{bs}" height="{bs}" rx="7" fill="{tile}"/>' + ''.join(
            f'<rect x="{x:.2f}" y="{y:.2f}" width="8.5" height="8.5" rx="2" fill="{accent if k == 1 else WHITE}"/>'
            for k, (x, y) in enumerate(cells))
    return cue(app, band) + letter + badge


def app_icon(app, rx):
    tile, _ = APPS[app]
    band = shade(tile, 0.78)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">'
            f'<defs><clipPath id="t"><rect width="120" height="120" rx="{rx}"/></clipPath></defs>'
            f'<g clip-path="url(#t)"><rect width="120" height="120" fill="{tile}"/><rect width="120" height="24" fill="{band}"/></g>'
            f'{app_content(app)}</svg>')


def adaptive_background(app):
    tile, _ = APPS[app]
    band = shade(tile, 0.78)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">'
            f'<rect width="108" height="108" fill="{tile}"/><rect width="108" height="32.4" fill="{band}"/></svg>')


def adaptive_foreground(app):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">'
            f'<g transform="translate(18 18) scale(0.6)">{app_content(app)}</g></svg>')


def adaptive_monochrome(app):
    """Single-color silhouette for Android 13+ themed icons (system tints it)."""
    letter, box = r_letter(WHITE, 58, 75, 58)
    if app == 'tasks':
        p = check_path(box)
        cut = (f'<path d="{toe_trim(box)}" fill="black"/>'
               f'<path d="{p}" fill="none" stroke="black" stroke-width="22" stroke-linejoin="round" stroke-linecap="round"/>'
               f'<path d="{p}" fill="none" stroke="white" stroke-width="9" stroke-linejoin="round" stroke-linecap="round"/>')
        cues = f'<rect x="43" y="12" width="34" height="18" rx="6" fill="white"/><rect x="53" y="17" width="14" height="5" rx="2.5" fill="black"/>'
    else:
        (bx, by, bs), cells = grid_cells(box)
        cut = f'<rect x="{bx:.2f}" y="{by:.2f}" width="{bs}" height="{bs}" rx="7" fill="black"/>' + ''.join(
            f'<rect x="{x:.2f}" y="{y:.2f}" width="8.5" height="8.5" rx="2" fill="white"/>' for x, y in cells)
        cues = '<rect x="36" y="9" width="9" height="22" rx="4.5" fill="white"/><rect x="75" y="9" width="9" height="22" rx="4.5" fill="white"/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="108" height="108">'
            f'<g transform="translate(18 18) scale(0.6)">{cues}{letter}{cut}</g></mask></defs>'
            f'<rect width="108" height="108" fill="{WHITE}" mask="url(#m)"/></svg>')


def studio_icon(rx):
    letter, (x, y, w, h) = r_letter(WHITE, 58, 62, 58)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">'
            f'<rect width="120" height="120" rx="{rx}" fill="{CHARCOAL}"/>{letter}'
            f'<rect x="{x + w + 3:.2f}" y="{y - 11:.2f}" width="12" height="12" rx="2.5" fill="{RED}"/></svg>')


# ---- Wordmark (font units, cap top at y=0, baseline at y=750) --------------
TRACK = -25  # -2px at 80px, as on the concept page


def run(chars, weight, x, fill):
    parts = []
    for ch in chars:
        g = G[f'{ch}{weight}']
        parts.append(f'<path fill="{fill}" transform="translate({x:.1f} 750) scale(1 -1)" d="{g["d"]}"/>')
        x += g['adv'] + TRACK
    return ''.join(parts), x - TRACK


def wordmark(ink, muted, apps=True, icon=False):
    x0 = 1750 if icon else 0
    rocis, end = run('ROCIs', 700, x0, ink)
    o_x = x0 + G['R700']['adv'] + TRACK
    ob = G['O700']['bounds']
    square = f'<rect x="{o_x + ob[2] - 110:.1f}" y="-140" width="188" height="188" rx="38" fill="{RED}"/>'
    body = rocis + square
    width = end
    if apps:
        word, width = run('Apps', 400, end + 275, muted)
        body += word
    if icon:
        # Icon centred on the cap-height middle, 1375 units tall (110px at 80px type).
        body = f'<g transform="translate(0 {375 - 687.5}) scale({1375 / 120})">' + studio_icon(27)[studio_icon(27).index('>') + 1:-6] + '</g>' + body
    top = 375 - 687.5 if icon else -160
    bottom = 375 + 687.5 if icon else 780
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-20 {top - 20:.1f} {width + 40:.1f} {bottom - top + 40:.1f}" '
            f'role="img" aria-label="{"ROCIs Apps" if apps else "ROCIs"}">{body}</svg>')


LIGHT = ('#1D1F22', '#5D6168')
DARK = ('#EEEEEC', '#A2A5AB')

files = {
    'rocis-r.svg': f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="60 -10 777 770">'
                   f'<path fill="currentColor" transform="translate(0 750) scale(1 -1)" d="{R["d"]}"/></svg>',
    'studio-icon.svg': studio_icon(27),
    'studio-icon-square.svg': studio_icon(0),
    'wordmark-rocis-apps-light.svg': wordmark(*LIGHT),
    'wordmark-rocis-apps-dark.svg': wordmark(*DARK),
    'lockup-rocis-apps-light.svg': wordmark(*LIGHT, icon=True),
    'lockup-rocis-apps-dark.svg': wordmark(*DARK, icon=True),
    'wordmark-rocis-light.svg': wordmark(*LIGHT, apps=False),
    'wordmark-rocis-dark.svg': wordmark(*DARK, apps=False),
}
for app in APPS:
    files[f'{app}-icon.svg'] = app_icon(app, 27)
    files[f'{app}-icon-square.svg'] = app_icon(app, 0)
    files[f'{app}-adaptive-background.svg'] = adaptive_background(app)
    files[f'{app}-adaptive-foreground.svg'] = adaptive_foreground(app)
    files[f'{app}-adaptive-monochrome.svg'] = adaptive_monochrome(app)

for name, svg in files.items():
    with open(os.path.join(OUT, name), 'w', encoding='utf-8', newline='\n') as f:
        f.write(svg + '\n')
print(len(files), 'files ->', OUT)

