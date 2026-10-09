"""
Generates inst/extdata/skeleton_polygons.csv from the accessioned SVG.

Unlike an earlier version (which kept only the bone-identified "outline"
paths and so looked flat), this keeps EVERY path in the SVG -- outline,
shading and other-detail -- in original document order, together with its
own fill / stroke / opacity. Document order is the SVG paint order, and
shading paths are interleaved with (both before and after) the outlines, so
drawing rows in `order_index` order reproduces the artwork faithfully.

Only outline paths carry a bone_name (blank for shading / other-detail).

Run from data-raw/:  python3 02_build_polygon_geometry.py
"""
import re
import csv
from flatten_paths import parse_path_to_subpaths

SVG_PATH = "../inst/extdata/LadyofHats_skeleton_bone_accessioned.svg"
OUT_PATH = "../inst/extdata/skeleton_polygons.csv"
VB_H = 925.702          # must match the SVG viewBox height (y is flipped)
CURVE_SAMPLES = 5       # line segments per bezier curve
GRADIENT_FALLBACK = "#DDC16D"  # 2 other-detail paths use SVG gradients ggplot2 can't draw


def attr(tag, name):
    m = re.search(r'(?:\s)' + re.escape(name) + r'="([^"]*)"', tag)
    return m.group(1) if m else None


def main():
    content = open(SVG_PATH).read()
    rows, n = [], 0
    for order_index, m in enumerate(re.finditer(r'<path\b[^>]*?/>', content), start=1):
        tag = m.group(0)
        d = attr(tag, "d")
        if not d:
            continue
        fill = attr(tag, "fill")
        if fill is None:
            fill = "#000000"            # SVG default fill
        elif fill.startswith("url("):
            fill = GRADIENT_FALLBACK
        stroke = attr(tag, "stroke") or "none"   # SVG default stroke is none
        stroke_width = attr(tag, "stroke-width") or "1"
        opacity = attr(tag, "opacity") or "1"
        role = attr(tag, "data-anatomical-role") or ""
        bone = attr(tag, "data-bone-name") or ""
        conf = attr(tag, "data-bone-confidence") or ""
        path_id = attr(tag, "id") or ""
        n += 1
        for sub_idx, sub in enumerate(parse_path_to_subpaths(d, curve_samples=CURVE_SAMPLES)):
            if len(sub) < 3:
                continue
            for order, (x, y) in enumerate(sub):
                rows.append([order_index, path_id, role, bone, conf, fill, stroke,
                             stroke_width, opacity, sub_idx, order,
                             round(x, 2), round(VB_H - y, 2)])

    with open(OUT_PATH, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["order_index", "path_id", "role", "bone_name", "confidence", "fill",
                    "stroke", "stroke_width", "opacity", "subpath_id", "vertex_order", "x", "y"])
        w.writerows(rows)
    print(f"{n} paths -> {len(rows)} vertex rows -> {OUT_PATH}")


if __name__ == "__main__":
    main()
