"""Tiny adb driver: emu.py shot NAME | tap X Y | tapt TEXT [n] | find TEXT | type TEXT | key CODE | swipe X1 Y1 X2 Y2 [ms] | dump"""
import os, re, subprocess, sys, time

ADB = os.path.expandvars(r'%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe')
OUT = os.path.join(os.path.dirname(__file__), 'emu')
os.makedirs(OUT, exist_ok=True)


def adb(*args, capture=True):
    return subprocess.run([ADB, *args], capture_output=capture).stdout


def dump():
    adb('shell', 'uiautomator', 'dump', '/sdcard/ui.xml')
    return adb('exec-out', 'cat', '/sdcard/ui.xml').decode('utf-8', 'replace')


def nodes(xml):
    for m in re.finditer(r'<node [^>]*>', xml):
        n = m.group(0)
        text = re.search(r' text="([^"]*)"', n).group(1)
        desc = re.search(r'content-desc="([^"]*)"', n).group(1)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        x1, y1, x2, y2 = map(int, b.groups())
        yield (text or desc), (x1 + x2) // 2, (y1 + y2) // 2, (x1, y1, x2, y2)


def find(label):
    xml = dump()
    return [n for n in nodes(xml) if label.lower() in n[0].lower()]


cmd = sys.argv[1]
if cmd == 'shot':
    path = os.path.join(OUT, sys.argv[2] + '.png')
    with open(path, 'wb') as f:
        f.write(adb('exec-out', 'screencap', '-p'))
    print(path)
elif cmd == 'tap':
    adb('shell', 'input', 'tap', sys.argv[2], sys.argv[3])
elif cmd in ('tapt', 'find'):
    hits = find(sys.argv[2])
    if cmd == 'find' or not hits:
        for h in hits:
            print(repr(h[0][:60]), h[1], h[2])
        if not hits:
            print('NOT FOUND:', sys.argv[2])
        sys.exit(0 if hits else 1)
    idx = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    _, x, y, _ = hits[idx]
    adb('shell', 'input', 'tap', str(x), str(y))
    print('tapped', repr(hits[idx][0][:40]), x, y)
elif cmd == 'type':
    adb('shell', 'input', 'text', sys.argv[2].replace(' ', '%s'))
elif cmd == 'key':
    adb('shell', 'input', 'keyevent', sys.argv[2])
elif cmd == 'swipe':
    adb('shell', 'input', 'swipe', *sys.argv[2:6], *(sys.argv[6:7] or ['300']))
elif cmd == 'dump':
    for n in nodes(dump()):
        if n[0].strip():
            print(repr(n[0][:70]), n[1], n[2])
time.sleep(0.8)
