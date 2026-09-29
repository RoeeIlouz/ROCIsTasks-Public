"""Play store listing tool (reuses publish_internal.py auth).

  inspect                       read-only: listings + image counts per language
  upload <dir> [--commit]       <dir>/<lang>/phone/*.png + <dir>/<lang>/feature.png
                                replaces phoneScreenshots/featureGraphic per language;
                                without --commit the edit is validated then discarded.
  graphics <store_dir> <icon.png> [--commit]
                                icon + <store_dir>/<deck>/feature.jpg for every existing
                                listing language (deck = language prefix, iw -> he, falls
                                back to en). PLAY_PKG selects the app (default Tasks).
"""
import glob, json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, '.agent', 'skills', 'rocis-autonomous-release', 'scripts'))
import publish_internal as pi  # noqa: E402
import requests  # noqa: E402

PKG = os.environ.get('PLAY_PKG') or 'com.rocisapps.tasks'  # empty string must not win
BASE = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}/edits'
UPLOAD = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}/edits'

creds = pi.find_credentials(ROOT)
token = pi.get_access_token(creds)
H = {'Authorization': f'Bearer {token}'}

edit = requests.post(BASE, headers=H, timeout=30)
edit.raise_for_status()
eid = edit.json()['id']
committed = False
try:
    if sys.argv[1] == 'inspect':
        listings = requests.get(f'{BASE}/{eid}/listings', headers=H, timeout=30).json().get('listings', [])
        details = requests.get(f'{BASE}/{eid}/details', headers=H, timeout=30).json()
        print('default language:', details.get('defaultLanguage'))
        for l in listings:
            lang = l['language']
            counts = {}
            for t in ('phoneScreenshots', 'featureGraphic'):
                imgs = requests.get(f'{BASE}/{eid}/listings/{lang}/{t}', headers=H, timeout=30).json().get('images', [])
                counts[t] = len(imgs)
            print(f"{lang:6} title={l.get('title')!r} short={l.get('shortDescription','')[:60]!r} {counts}")
    elif sys.argv[1] == 'store':
        # store <exports_root> [--commit]: listing text from listings.json (new languages)
        # + <exports_root>/<deck>/phone/*.png and feature.png for every language incl. en-US.
        root = sys.argv[2]
        cfg = json.load(open(os.path.join(ROOT, 'tools', 'store-screenshots', 'listings.json'), encoding='utf-8'))
        targets = {'en-US': 'en'}
        for lang, v in cfg.items():
            if lang.startswith('_'):
                continue
            body = {k: v[k] for k in ('title', 'shortDescription', 'fullDescription')}
            r = requests.put(f'{BASE}/{eid}/listings/{lang}', headers=H, json=body, timeout=60)
            r.raise_for_status()
            print(f'{lang}: listing text')
            targets[lang] = v['deck']
        for lang, deck in targets.items():
            deck_dir = os.path.join(root, deck)
            for t in ('phoneScreenshots', 'featureGraphic'):
                files = sorted(glob.glob(os.path.join(deck_dir, 'phone', '*.png'))) if t == 'phoneScreenshots'                     else [f for f in [os.path.join(deck_dir, 'feature.png')] if os.path.exists(f)]
                if not files:
                    continue
                requests.delete(f'{BASE}/{eid}/listings/{lang}/{t}', headers=H, timeout=60).raise_for_status()
                for f in files:
                    with open(f, 'rb') as fh:
                        r = requests.post(f'{UPLOAD}/{eid}/listings/{lang}/{t}?uploadType=media',
                                          headers={**H, 'Content-Type': 'image/png'}, data=fh.read(), timeout=120)
                    r.raise_for_status()
                print(f'{lang}: {t} <- {len(files)} ({deck})')
        v = requests.post(f'{BASE}/{eid}:validate', headers=H, timeout=60)
        print('validate:', v.status_code, v.text[:500] if v.status_code != 200 else 'ok')
        if '--commit' in sys.argv and v.status_code == 200:
            c = requests.post(f'{BASE}/{eid}:commit', headers=H, timeout=120)
            print('commit:', c.status_code, c.text[:500] if c.status_code != 200 else 'ok')
            committed = c.status_code == 200
    elif sys.argv[1] == 'graphics':
        store_dir, icon = sys.argv[2], sys.argv[3]
        langs = [l['language'] for l in requests.get(f'{BASE}/{eid}/listings', headers=H, timeout=30).json().get('listings', [])]
        for lang in langs:
            prefix = lang.split('-')[0]
            deck = 'he' if prefix == 'iw' else prefix
            feature = os.path.join(store_dir, deck, 'feature.jpg')
            if not os.path.exists(feature):
                feature = os.path.join(store_dir, 'en', 'feature.jpg')
            for t, path, mime in (('icon', icon, 'image/png'), ('featureGraphic', feature, 'image/jpeg')):
                requests.delete(f'{BASE}/{eid}/listings/{lang}/{t}', headers=H, timeout=60).raise_for_status()
                with open(path, 'rb') as fh:
                    r = requests.post(f'{UPLOAD}/{eid}/listings/{lang}/{t}?uploadType=media',
                                      headers={**H, 'Content-Type': mime}, data=fh.read(), timeout=120)
                r.raise_for_status()
            print(f'{lang}: icon + featureGraphic <- {os.path.relpath(feature, store_dir)}')
        v = requests.post(f'{BASE}/{eid}:validate', headers=H, timeout=60)
        print('validate:', v.status_code, v.text[:300] if v.status_code != 200 else 'ok')
        if '--commit' in sys.argv and v.status_code == 200:
            c = requests.post(f'{BASE}/{eid}:commit', headers=H, timeout=120)
            print('commit:', c.status_code, c.text[:300] if c.status_code != 200 else 'ok')
            committed = c.status_code == 200
    elif sys.argv[1] == 'upload':
        src = sys.argv[2]
        existing = {l['language'] for l in requests.get(f'{BASE}/{eid}/listings', headers=H, timeout=30).json().get('listings', [])}
        for lang_dir in sorted(glob.glob(os.path.join(src, '*'))):
            lang = os.path.basename(lang_dir)
            if lang not in existing:
                print(f'skip {lang}: no listing for this language')
                continue
            for t in ('phoneScreenshots', 'featureGraphic'):
                files = sorted(glob.glob(os.path.join(lang_dir, 'phone', '*.png'))) if t == 'phoneScreenshots' \
                    else [f for f in [os.path.join(lang_dir, 'feature.png')] if os.path.exists(f)]
                if not files:
                    continue
                r = requests.delete(f'{BASE}/{eid}/listings/{lang}/{t}', headers=H, timeout=60)
                r.raise_for_status()
                for f in files:
                    with open(f, 'rb') as fh:
                        r = requests.post(f'{UPLOAD}/{eid}/listings/{lang}/{t}?uploadType=media',
                                          headers={**H, 'Content-Type': 'image/png'}, data=fh.read(), timeout=120)
                    r.raise_for_status()
                print(f'{lang}: {t} <- {len(files)} image(s)')
        v = requests.post(f'{BASE}/{eid}:validate', headers=H, timeout=60)
        print('validate:', v.status_code, v.text[:300] if v.status_code != 200 else 'ok')
        if '--commit' in sys.argv and v.status_code == 200:
            c = requests.post(f'{BASE}/{eid}:commit', headers=H, timeout=120)
            print('commit:', c.status_code, c.text[:300] if c.status_code != 200 else 'ok')
            committed = c.status_code == 200
finally:
    if not committed:
        requests.delete(f'{BASE}/{eid}', headers=H, timeout=30)
