"""Copy per-language captures into the editor and fill localized captions."""
import io, json, os, shutil

HERE = os.path.dirname(__file__)
TOOL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ['en', 'he', 'ar', 'es', 'de', 'fr', 'sv', 'hi']
# deck file -> capture name (slide 6 in English shows the Hebrew RTL widgets)
MAP = {
    '01.png': '01_home_upnext_month', '02.png': '02_home_fullcalendar',
    '03.png': '03_dark_fullcalendar', '04.png': '04_app_tasks',
    '05.png': '05_app_calendar', '06.png': '06_app_kanban',
    '07.png': '07_dark_upnext_month', '09.png': '09_home_dayagenda',
}
for lang in LANGS:
    dst = os.path.join(TOOL, 'public', 'screenshots', 'android', 'phone', lang)
    os.makedirs(dst, exist_ok=True)
    for deck, cap in MAP.items():
        src_lang = 'he' if (lang == 'en' and deck == '07.png') else lang
        src = os.path.join(HERE, 'emu', 'loc', src_lang, cap + '.png')
        shutil.copyfile(src, os.path.join(dst, deck))
    stale = os.path.join(dst, '08.png')
    if os.path.exists(stale):
        os.remove(stale)

copy = json.load(io.open(os.path.join(TOOL, 'copy.json'), encoding='utf-8'))
p = os.path.join(TOOL, 'app-store-screenshots.json')
d = json.load(io.open(p, encoding='utf-8'))
d['locales'] = LANGS
d['locale'] = 'en'
d['device'] = 'android'
for s in d['slidesByDevice']['android']:
    n = s['id'].split('_')[1]
    s['label'] = {l: copy[l][n][0] for l in LANGS}
    s['headline'] = {l: copy[l][n][1] for l in LANGS}
for s in d['slidesByDevice']['feature-graphic']:
    s['headline'] = {l: copy[l]['fg'] for l in LANGS}
io.open(p, 'w', encoding='utf-8', newline='\n').write(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
print('ok', [s['screenshot'] for s in d['slidesByDevice']['android']])
