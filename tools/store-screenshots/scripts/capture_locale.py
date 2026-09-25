"""Capture store screenshots for one app language: capture_locale.py <lang>"""
import os, subprocess, sys, time

HERE = os.path.dirname(__file__)
ADB = os.path.expandvars(r'%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe')
FLAGS = {  # flag emoji as uiautomator reports it
    'en': '&#127482;&#127480;', 'hi': '&#127470;&#127475;', 'he': '&#127470;&#127473;',
    'es': '&#127466;&#127480;', 'ar': '&#127480;&#127462;', 'sv': '&#127480;&#127466;',
    'de': '&#127465;&#127466;', 'fr': '&#127467;&#127479;',
}
RTL = {'he', 'ar'}
lang = sys.argv[1]
out = os.path.join(HERE, 'emu', 'loc', lang)
os.makedirs(out, exist_ok=True)


def emu(*args):
    r = subprocess.run([sys.executable, os.path.join(HERE, 'emu.py'), *args],
                       capture_output=True, text=True, encoding='utf-8', env={**os.environ, 'PYTHONIOENCODING': 'utf-8'})
    return r.stdout


def adb(*args):
    subprocess.run([ADB, *args], capture_output=True)


def shot(name):
    with open(os.path.join(out, name + '.png'), 'wb') as f:
        f.write(subprocess.run([ADB, 'exec-out', 'screencap', '-p'], capture_output=True).stdout)


def launch(wait=8):
    adb('shell', 'monkey', '-p', 'com.rocisapps.tasks', '-c', 'android.intent.category.LAUNCHER', '1')
    time.sleep(wait)


def current_rtl():
    # Tasks tab sits on the right in RTL.
    return any(line for line in emu('dump').splitlines() if line.endswith(' 870 2203') and 'Settings' not in line) and False


def settings_tab(rtl):
    emu('tap', '210' if rtl else '870', '2203')
    time.sleep(2)


def tasks_tab(rtl):
    emu('tap', '870' if rtl else '210', '2203')
    time.sleep(2)


def set_language(target, rtl_now):
    settings_tab(rtl_now)
    for _ in range(6):  # start from the top
        emu('swipe', '540', '800', '540', '1700', '250')
    rows = []
    for _ in range(8):  # then scroll down to the language row
        rows = [l for l in emu('dump').splitlines() if any(f in l for f in FLAGS.values())]
        if rows:
            break
        emu('swipe', '540', '1600', '540', '1000', '300')
    if not rows:
        raise SystemExit('language row not found')
    x, y = rows[0].rsplit(' ', 2)[1:]
    emu('tap', x, y)
    time.sleep(2)
    for _ in range(3):
        hits = [l for l in emu('dump').splitlines() if FLAGS[target] + '&#10;' in l]
        if hits:
            x, y = hits[0].rsplit(' ', 2)[1:]
            emu('tap', x, y)
            time.sleep(3)
            return
        emu('swipe', '540', '2000', '540', '1400', '300')
    raise SystemExit('target language not found')


def home_page(n):
    emu('key', '3')  # back to the launcher (last page viewed)
    time.sleep(2)
    emu('key', '3')  # a second Home jumps to the default page
    time.sleep(2)
    for _ in range(n):
        emu('swipe', '900', '1000', '150', '1000', '300')
        time.sleep(2)
    time.sleep(1.5)


rtl_before = sys.argv[2] == 'rtl' if len(sys.argv) > 2 else False
adb('shell', 'cmd', 'uimode', 'night', 'no')
launch()
set_language(lang, rtl_before)
adb('shell', 'am', 'force-stop', 'com.rocisapps.tasks')
now = subprocess.run([ADB, 'shell', 'date', '+%H%M'], capture_output=True, text=True).stdout.strip()
adb('shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', 'clock', '-e', 'hhmm', now)
launch(10)  # reseeds in the new language and refreshes widgets
rtl = lang in RTL
tasks_tab(rtl)
shot('04_app_tasks')
emu('tap', '540', '2203')
time.sleep(3)
shot('05_app_calendar')
tasks_tab(rtl)
emu('tap', '1006' if rtl else '74', '206')  # board toggle (leading icon)
time.sleep(3)
shot('06_app_kanban')
emu('tap', '1006' if rtl else '74', '206')
time.sleep(1)
home_page(1); shot('01_home_upnext_month')
home_page(2); shot('02_home_fullcalendar')
home_page(3); shot('09_home_dayagenda')
adb('shell', 'cmd', 'uimode', 'night', 'yes')
time.sleep(3)
adb('shell', 'am', 'force-stop', 'com.rocisapps.tasks')
launch(9)  # a fresh start redraws every widget in dark
home_page(2); shot('03_dark_fullcalendar')
home_page(1); shot('07_dark_upnext_month')
adb('shell', 'cmd', 'uimode', 'night', 'no')
time.sleep(3)
adb('shell', 'am', 'force-stop', 'com.rocisapps.tasks')
launch(9)
print('captured', lang, sorted(os.listdir(out)))
