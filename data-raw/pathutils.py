import re

def parse_path_points(d):
    """Return list of (x,y) points approximating the path (all anchor + control points)."""
    tokens = re.findall(r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?', d)
    pts = []
    cur = [0.0, 0.0]
    start = [0.0, 0.0]
    cmd = None
    i = 0
    def nextnum():
        nonlocal i
        v = float(tokens[i]); i += 1
        return v
    while i < len(tokens):
        t = tokens[i]
        if re.match(r'^[MmLlHhVvCcSsQqTtAaZz]$', t):
            cmd = t
            i += 1
        else:
            if cmd is None:
                i += 1
                continue
        if cmd in ('M','m'):
            x = nextnum(); y = nextnum()
            if cmd == 'm':
                x += cur[0]; y += cur[1]
            cur = [x,y]; start = cur[:]
            pts.append(tuple(cur))
            cmd = 'L' if cmd=='M' else 'l'  # subsequent coords are lineto
        elif cmd in ('L','l'):
            x = nextnum(); y = nextnum()
            if cmd == 'l':
                x += cur[0]; y += cur[1]
            cur = [x,y]
            pts.append(tuple(cur))
        elif cmd in ('H','h'):
            x = nextnum()
            if cmd == 'h':
                x += cur[0]
            cur = [x, cur[1]]
            pts.append(tuple(cur))
        elif cmd in ('V','v'):
            y = nextnum()
            if cmd == 'v':
                y += cur[1]
            cur = [cur[0], y]
            pts.append(tuple(cur))
        elif cmd in ('C','c'):
            x1=nextnum(); y1=nextnum(); x2=nextnum(); y2=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 'c':
                x1+=cur[0]; y1+=cur[1]; x2+=cur[0]; y2+=cur[1]; x+=cur[0]; y+=cur[1]
            pts.append((x1,y1)); pts.append((x2,y2)); pts.append((x,y))
            cur = [x,y]
        elif cmd in ('S','s'):
            x2=nextnum(); y2=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 's':
                x2+=cur[0]; y2+=cur[1]; x+=cur[0]; y+=cur[1]
            pts.append((x2,y2)); pts.append((x,y))
            cur = [x,y]
        elif cmd in ('Q','q'):
            x1=nextnum(); y1=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 'q':
                x1+=cur[0]; y1+=cur[1]; x+=cur[0]; y+=cur[1]
            pts.append((x1,y1)); pts.append((x,y))
            cur = [x,y]
        elif cmd in ('T','t'):
            x=nextnum(); y=nextnum()
            if cmd == 't':
                x+=cur[0]; y+=cur[1]
            pts.append((x,y))
            cur = [x,y]
        elif cmd in ('A','a'):
            rx=nextnum(); ry=nextnum(); rot=nextnum(); laf=nextnum(); sf=nextnum(); x=nextnum(); y=nextnum()
            if cmd == 'a':
                x+=cur[0]; y+=cur[1]
            pts.append((x,y))
            cur = [x,y]
        elif cmd in ('Z','z'):
            cur = start[:]
            pts.append(tuple(cur))
        else:
            i += 1
    return pts

def bbox_and_centroid(d):
    pts = parse_path_points(d)
    if not pts:
        return None
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    minx,maxx = min(xs), max(xs)
    miny,maxy = min(ys), max(ys)
    cx = (minx+maxx)/2; cy = (miny+maxy)/2
    return (minx,miny,maxx,maxy,cx,cy)
