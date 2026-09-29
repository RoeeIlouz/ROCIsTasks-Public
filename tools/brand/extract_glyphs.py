"""Instance Unbounded and export glyph outlines (SVG path, bounds, advance) as JSON."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'pylib'))  # optional local install: pip install --target pylib fonttools

from fontTools.ttLib import TTFont  # noqa: E402
from fontTools.varLib import instancer  # noqa: E402
from fontTools.pens.svgPathPen import SVGPathPen  # noqa: E402
from fontTools.pens.boundsPen import BoundsPen  # noqa: E402

out = {}
for weight, chars in ((700, 'ROCIs'), (400, 'Aps')):
    font = instancer.instantiateVariableFont(TTFont(os.path.join(HERE, 'Unbounded-VF.ttf')), {'wght': weight})
    gs = font.getGlyphSet()
    cmap = font.getBestCmap()
    hmtx = font['hmtx']
    for ch in chars:
        name = cmap[ord(ch)]
        pen, bpen = SVGPathPen(gs), BoundsPen(gs)
        gs[name].draw(pen)
        gs[name].draw(bpen)
        out[f'{ch}{weight}'] = {'d': pen.getCommands(), 'bounds': list(bpen.bounds), 'adv': hmtx[name][0]}
    out['upm'] = font['head'].unitsPerEm

with open(os.path.join(HERE, 'unbounded_glyphs.json'), 'w', encoding='utf-8') as f:
    json.dump(out, f)
print({k: (round(v['adv']), [round(b) for b in v['bounds']]) for k, v in out.items() if k != 'upm'})

