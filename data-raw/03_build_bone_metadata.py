"""
Generates inst/extdata/bone_metadata.csv: one row per distinct bone_name,
classified into a bone_type (which controls the location vocabulary
resolve_location() allows -- see R/resolve_location.R) plus side (R/L/NA).

Run from the data-raw/ directory, after 02_build_polygon_geometry.py:
    python3 03_build_bone_metadata.py
"""
import csv
import re

POLYGONS_PATH = "../inst/extdata/skeleton_polygons.csv"
OUT_PATH = "../inst/extdata/bone_metadata.csv"


def classify(name):
    if "vertebra" in name:
        bt = "vertebra"
    elif name in ("cranium", "mandible") or any(
        k in name for k in ["maxilla", "zygomatic", "orbit", "nasal_bone", "temporal_bone"]
    ):
        bt = "skull_bone"
    elif name in ("teeth_upper", "teeth_lower", "hand_R", "hand_L", "foot_R", "foot_L"):
        bt = "grouped_region"
    elif any(k in name for k in ["humerus", "radius", "ulna", "femur", "tibia", "fibula", "clavicle"]):
        bt = "long_bone"
    elif "patella" in name:
        bt = "sesamoid"
    elif "scapula" in name or "sternum" in name or "costal_cartilage" in name:
        bt = "flat_bone"
    elif "rib" in name:
        bt = "rib"
    elif any(k in name for k in ["pelvis", "sacrum", "coccyx"]):
        bt = "irregular_bone"
    elif "joint" in name or "iliac_crest" in name:
        bt = "irregular_bone"
    else:
        bt = "irregular_bone"  # fallback -- review anything landing here

    side_match = re.search(r"(?:^|_)(R|L)(?:_|$)", name)
    side = side_match.group(1) if side_match else ""
    return bt, side


def main():
    seen = {}
    with open(POLYGONS_PATH) as f:
        for row in csv.DictReader(f):
            if row["bone_name"]:          # shading / other-detail rows have no bone_name
                seen[row["bone_name"]] = row["confidence"]

    rows = []
    for name, confidence in sorted(seen.items()):
        bone_type, side = classify(name)
        rows.append([name, bone_type, side, confidence])

    with open(OUT_PATH, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["bone_name", "bone_type", "side", "confidence"])
        w.writerows(rows)

    print(f"Classified {len(rows)} distinct bones -> {OUT_PATH}")
    print("Review any bones you don't recognise -- 'irregular_bone' is the fallback bucket.")


if __name__ == "__main__":
    main()
