# data-raw

Scripts that build the three files in `inst/extdata/` from the source SVG.
Written in Python (not R) because the accessioning work -- rendering the
SVG, visually identifying which path is which bone -- was done that way
originally; there's no dependency on this at package-load time, these are
only for regenerating the shipped CSVs if you extend or correct the
accessioning.

Pipeline, in order:

1. **`01_accession_bones.py`** -- reads the raw LadyofHats SVG (before
   accessioning: paths tagged only with `data-anatomical-role`, no bone
   identity) and adds `data-bone-name` / `data-bone-confidence` attributes
   to every `outline`-role path, based on a mix of explicit id-based
   assignment (for visually-confirmed bones) and positional rules (for the
   grouped hand/foot/teeth regions). Produces
   `LadyofHats_skeleton_bone_accessioned.svg` and `bone_accession.csv`.
   Depends on `pathutils.py` for bounding-box/centroid calculation.

2. **`02_build_polygon_geometry.py`** -- reads the accessioned SVG and
   flattens each bone-identified path's curves into a polyline (via
   `flatten_paths.py`), producing `skeleton_polygons.csv` -- the vertex
   table `plot_skeleton_base()` and friends actually plot.

3. **`03_build_bone_metadata.py`** -- reads the distinct bone names out of
   `skeleton_polygons.csv` and classifies each into a `bone_type` (which
   controls what `region`/`side_position` vocabulary `resolve_location()`
   accepts -- see `R/resolve_location.R`) and a `side`.

## If you correct or extend the accessioning

The `confidence` column in `bone_accession.csv` / `bone_metadata.csv` flags
what's worth checking first (see the main README's "Accessioning
confidence" section) -- particularly thoracic vertebra numbering, rib
numbering past rib 9, and the two `*_lower_margin_uncertain` fragments.

To fix a specific bone's identity: edit the `add(...)` call for that path
id in `01_accession_bones.py`, then re-run all three scripts in order.

To add a new bone_type (e.g. if you split `grouped_region` into finer
per-digit hand locations): add it to `classify()` in
`03_build_bone_metadata.py`, then add a matching branch to
`.region_vocabulary()` / `.side_vocabulary()` in `../R/resolve_location.R`.

## Dependencies

Pure Python standard library only (`re`, `csv`) -- no packages to install.
