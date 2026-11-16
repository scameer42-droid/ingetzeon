import re, sys, xml.etree.ElementTree as ET
path, needle = sys.argv[1], sys.argv[2].lower()
try:
    root = ET.parse(path).getroot()
except Exception:
    sys.exit(0)
best = None
for n in root.iter('node'):
    t = (n.get('text') or '') + ' ' + (n.get('content-desc') or '')
    if needle in t.lower():
        m = re.findall(r'\d+', n.get('bounds') or '')
        if len(m) == 4:
            x1, y1, x2, y2 = map(int, m)
            area = (x2 - x1) * (y2 - y1)
            if best is None or area < best[0]:
                best = (area, (x1 + x2) // 2, (y1 + y2) // 2)
if best:
    print(best[1], best[2])
