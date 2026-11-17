import re, sys, xml.etree.ElementTree as ET
path, needle = sys.argv[1], sys.argv[2].lower()
mode = sys.argv[3] if len(sys.argv) > 3 else ''
try:
    root = ET.parse(path).getroot()
except Exception:
    sys.exit(0)
best = None
for n in root.iter('node'):
    parts = [(n.get('text') or '').strip().lower(), (n.get('content-desc') or '').strip().lower()]
    ok = any(p == needle for p in parts) if mode in ('exact', 'last') else needle in ' '.join(parts)
    if not ok:
        continue
    m = re.findall(r'\d+', n.get('bounds') or '')
    if len(m) != 4:
        continue
    x1, y1, x2, y2 = map(int, m)
    area = (x2 - x1) * (y2 - y1)
    key = -y1 if mode == 'last' else area
    if best is None or key < best[0]:
        best = (key, (x1 + x2) // 2, (y1 + y2) // 2)
if best:
    print(best[1], best[2])
