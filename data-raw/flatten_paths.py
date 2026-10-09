import re

def parse_path_to_subpaths(d, curve_samples=10):
    """Parse an SVG path 'd' string into a list of subpaths, each a list of (x,y) points,
    with bezier/quadratic curves flattened into line segments for polygon rendering."""
    tokens = re.findall(r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?', d)
    i = 0
    def nextnum():
        nonlocal i
        v = float(tokens[i]); i += 1
        return v

    subpaths = []
    cur_sub = []
    cur = [0.0, 0.0]
    start = [0.0, 0.0]
    cmd = None
    last_ctrl = None  # for S/T reflection

    def cubic_bezier(p0, p1, p2, p3, n):
        pts = []
        for k in range(1, n+1):
            t = k / n
            mt = 1 - t
            x = mt**3*p0[0] + 3*mt**2*t*p1[0] + 3*mt*t**2*p2[0] + t**3*p3[0]
            y = mt**3*p0[1] + 3*mt**2*t*p1[1] + 3*mt*t**2*p2[1] + t**3*p3[1]
            pts.append((x,y))
        return pts

    def quad_bezier(p0, p1, p2, n):
        pts = []
        for k in range(1, n+1):
            t = k / n
            mt = 1 - t
            x = mt**2*p0[0] + 2*mt*t*p1[0] + t**2*p2[0]
            y = mt**2*p0[1] + 2*mt*t*p1[1] + t**2*p2[1]
            pts.append((x,y))
        return pts

    while i < len(tokens):
        t = tokens[i]
        if re.match(r'^[MmLlHhVvCcSsQqTtAaZz]$', t):
            cmd = t
            i += 1
        elif cmd is None:
            i += 1
            continue

        if cmd in ('M','m'):
            x = nextnum(); y = nextnum()
            if cmd == 'm':
                x += cur[0]; y += cur[1]
            if cur_sub:
                subpaths.append(cur_sub)
            cur = [x,y]; start = cur[:]
            cur_sub = [tuple(cur)]
            cmd = 'L' if cmd=='M' else 'l'
            last_ctrl = None
        elif cmd in ('L','l'):
            x = nextnum(); y = nextnum()
            if cmd == 'l':
                x += cur[0]; y += cur[1]
            cur = [x,y]
            cur_sub.append(tuple(cur))
            last_ctrl = None
        elif cmd in ('H','h'):
            x = nextnum()
            if cmd == 'h':
                x += cur[0]
            cur = [x, cur[1]]
            cur_sub.append(tuple(cur))
            last_ctrl = None
        elif cmd in ('V','v'):
            y = nextnum()
            if cmd == 'v':
                y += cur[1]
            cur = [cur[0], y]
            cur_sub.append(tuple(cur))
            last_ctrl = None
        elif cmd in ('C','c'):
            x1=nextnum(); y1=nextnum(); x2=nextnum(); y2=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 'c':
                x1+=cur[0]; y1+=cur[1]; x2+=cur[0]; y2+=cur[1]; x+=cur[0]; y+=cur[1]
            pts = cubic_bezier(cur, (x1,y1), (x2,y2), (x,y), curve_samples)
            cur_sub.extend(pts)
            last_ctrl = (x2,y2)
            cur = [x,y]
        elif cmd in ('S','s'):
            x2=nextnum(); y2=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 's':
                x2+=cur[0]; y2+=cur[1]; x+=cur[0]; y+=cur[1]
            if last_ctrl:
                x1 = 2*cur[0]-last_ctrl[0]; y1 = 2*cur[1]-last_ctrl[1]
            else:
                x1,y1 = cur
            pts = cubic_bezier(cur, (x1,y1), (x2,y2), (x,y), curve_samples)
            cur_sub.extend(pts)
            last_ctrl = (x2,y2)
            cur = [x,y]
        elif cmd in ('Q','q'):
            x1=nextnum(); y1=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 'q':
                x1+=cur[0]; y1+=cur[1]; x+=cur[0]; y+=cur[1]
            pts = quad_bezier(cur, (x1,y1), (x,y), curve_samples)
            cur_sub.extend(pts)
            last_ctrl = (x1,y1)
            cur = [x,y]
        elif cmd in ('T','t'):
            x=nextnum(); y=nextnum()
            if cmd == 't':
                x+=cur[0]; y+=cur[1]
            if last_ctrl:
                x1 = 2*cur[0]-last_ctrl[0]; y1 = 2*cur[1]-last_ctrl[1]
            else:
                x1,y1 = cur
            pts = quad_bezier(cur, (x1,y1), (x,y), curve_samples)
            cur_sub.extend(pts)
            last_ctrl = (x1,y1)
            cur = [x,y]
        elif cmd in ('A','a'):
            rx=nextnum(); ry=nextnum(); rot=nextnum(); laf=nextnum(); sf=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 'a':
                x+=cur[0]; y+=cur[1]
            # simple approximation: straight line (arcs are rare/small in this dataset)
            cur_sub.append((x,y))
            cur = [x,y]
            last_ctrl = None
        elif cmd in ('Z','z'):
            cur = start[:]
            cur_sub.append(tuple(cur))
        else:
            i += 1

    if cur_sub:
        subpaths.append(cur_sub)
    return subpaths
