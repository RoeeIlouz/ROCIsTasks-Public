"""Open the screenshot editor, save a preview, optionally export bundles."""
import os, sys
from playwright.sync_api import sync_playwright

OUT = os.path.join(os.path.dirname(__file__), 'editor')
os.makedirs(OUT, exist_ok=True)
action = sys.argv[1] if len(sys.argv) > 1 else 'preview'

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={'width': 1800, 'height': 1100}, accept_downloads=True)
    page.goto('http://localhost:3100', wait_until='load')
    page.wait_for_timeout(4000)
    if action == 'preview':
        page.screenshot(path=os.path.join(OUT, 'editor.png'))
        # List visible buttons to learn the UI.
        for b in page.locator('button').all()[:60]:
            try:
                t = b.inner_text().strip().replace('\n', ' ')
                if t:
                    print('BTN', t[:50])
            except Exception:
                pass
    elif action == 'export':
        device = sys.argv[2]  # button label, e.g. "Android Phone" or "Feature Graphic"
        if device not in ('Android Phone', 'current'):
            page.get_by_text('Android Phone', exact=True).first.click()
            page.wait_for_timeout(800)
            page.get_by_text(device, exact=True).last.click()
            page.wait_for_timeout(2500)
        with page.expect_download(timeout=300000) as dl:
            page.get_by_text('Export bundle', exact=False).first.click()
        path = os.path.join(OUT, device.replace(' ', '_') + '.zip')
        dl.value.save_as(path)
        print('saved', path)
    browser.close()
