# skeletograph

Plots bioarchaeological skeletal observations onto a standard anterior-view
human skeleton, in the spirit of [gganatogram](https://github.com/jespermaag/gganatogram)
but built around a bone accessioning scheme for palaeopathology, trauma,
entheseal change, and taphonomic modification recording, with two separate
plotting modes:

1. **Individual observations** (`skeletograph_points()`) -- plot specific
   lesions/marks at anatomically-described locations (e.g. "midshaft,
   lateral femur"), one point per observation, shaped by category.
2. **Population-level heatmap** (`skeletograph_heatmap()`) -- aggregate
   observations across many individuals into a per-bone average, coloured
   as a continuous gradient.

## Installation

This isn't on CRAN. From the package source directory:

```r
# install.packages("devtools")
devtools::install()

# or, for iterative development:
devtools::load_all()
```

## Quick start

### 1. Individual observations

```r
library(skeletograph)
library(ggplot2)

observations <- data.frame(
  bone_name     = c("femur_R",        "tibia_L",   "cranium",  "clavicle_R"),
  category      = c("trauma",         "palaeopathology", "entheseal_change", "taphonomy"),
  region        = c("proximal_third", "midshaft",  "superior", "midshaft"),
  side_position = c("anterior",       "medial",    "left",     "central")
)
```

Wait -- `"anterior"` above is not a valid `side_position` (that's a
`surface`, see below). A corrected version:

```r
observations <- data.frame(
  bone_name     = c("femur_R",        "tibia_L",         "cranium",  "clavicle_R"),
  category      = c("trauma",         "palaeopathology", "entheseal_change", "taphonomy"),
  region        = c("proximal_third", "midshaft",        "superior", "midshaft"),
  side_position = c("lateral",        "medial",          "left",     "central")
)

plot_skeleton_base() +
  skeletograph_points(observations)
```

Not sure what terms are valid for a given bone? Check before you build your
data frame:

```r
skeletograph_vocabulary("femur_R")
#> $region:        proximal, proximal_third, midshaft, distal_third, distal
#> $side_position:  medial, central, lateral

skeletograph_vocabulary("cranium")
#> $region:        superior, central, inferior
#> $side_position:  right, central, left

skeletograph_vocabulary("hand_L")
#> $region:        central
#> $side_position:  central
```

`hand_L`, `hand_R`, `foot_L`, `foot_R`, `teeth_upper`, and `teeth_lower` are
**grouped regions** -- per your call on how to handle the hand/foot bones
and teeth, each carpal/metacarpal/phalanx/tooth is still its own separate
polygon in the underlying SVG, but they only resolve to a single "central"
location as one group for now. If you later want fine per-digit or
per-tooth placement, that's a vocabulary extension in
`R/resolve_location.R`, not a data change.

### 2. Population-level heatmap

```r
pop_data <- data.frame(
  bone_name = rep(c("femur_R", "femur_L", "tibia_R", "tibia_L"), times = c(8, 6, 5, 5)),
  category  = "trauma",
  value     = c(rep(1, 3), rep(0, 5),   # femur_R: 3/8 affected
                rep(1, 1), rep(0, 5),   # femur_L: 1/6 affected
                rep(1, 4), rep(0, 1),   # tibia_R: 4/5 affected
                rep(0, 5))              # tibia_L: 0/5 affected
)

skeletograph_heatmap(pop_data)
```

`value` can be anything you want aggregated -- a 0/1 presence flag (giving
you a prevalence-rate heatmap once averaged), a severity score, or a raw
count (pass `aggregate_fun = sum`). Bones with no rows in your data are
shown in `na_color` (default light grey) rather than left blank.

If your data has more than one `category` and you don't pass
`category_filter`, you get one small-multiple heatmap per category
(`facet_wrap(~category)`) rather than categories being blended into a
single number -- deliberately, since "average trauma" and "average
entheseal change" per bone aren't comparable on one scale.

## Colour palettes (MetBrewer)

Both [skeletograph_points()] and [skeletograph_heatmap()] default to colours
from **Hokusai1**, one of the palettes in the
[MetBrewer](https://github.com/BlakeRMills/MetBrewer) package by
**Blake Robert Mills** -- palettes drawn from works held at the
Metropolitan Museum of Art, this one after Katsushika Hokusai. All credit
for the palette itself belongs there; skeletograph just uses it as a
default. MetBrewer is a `Suggests` dependency (`install.packages("MetBrewer")`)
-- without it installed, both functions still work and fall back to a small
built-in colour set.

Swap palettes with the `palette` argument on either function -- anything
`MetBrewer::met.brewer()` accepts works (`"Renoir"`, `"Isfahan1"`, `"Klimt"`,
`"VanGogh1"`, and 50-odd others):

```r
plot_skeleton_base() + skeletograph_points(observations, palette = "Renoir")
skeletograph_heatmap(pop_data, palette = "Isfahan1")
```

Or build your own named vector and skip the palette system entirely:

```r
skeletograph_points(observations, colors = c(
  palaeopathology = "#1b9e77", trauma = "#d95f02",
  entheseal_change = "#7570b3", taphonomy = "#e7298a"
))
```

## The "surface" (anterior/posterior) limitation

The source artwork is a single **anterior-view** skeleton. An anterior vs.
posterior distinction on a bone can't be shown as a different (x, y)
position in a flat anterior projection -- both surfaces of, say, the femur
project onto the same spot. `resolve_location()` and `skeletograph_points()`
accept an optional `surface` column/argument and carry it through
unchanged on the resolved data, so you can map it to a different
aesthetic yourself if you need the distinction visually, e.g.:

```r
skeletograph_points(observations) # surface carried through, unused

# or build the layer yourself with surface mapped to e.g. alpha/fill:
resolved <- resolve_location("femur_R", "midshaft", "lateral", surface = "posterior")
```

Adding a true posterior-view skeleton later is the natural way to resolve
this properly -- see `data-raw/` for how the current SVG was accessioned,
which is the template for tracing/accessioning a posterior plate the same
way.

## Package contents / data provenance

- `inst/extdata/LadyofHats_skeleton_bone_accessioned.svg` -- the source
  skeleton artwork (LadyofHats human skeleton illustration, anterior view),
  with every anatomically-identified path carrying `data-bone-name` and
  `data-bone-confidence` attributes.
- `inst/extdata/bone_accession.csv` -- the raw per-SVG-path accessioning
  (`path_id`, `bone_name`, `confidence`, centroid, size). One row per SVG
  path (261 rows) -- several rows can share a `bone_name`.
- `inst/extdata/skeleton_polygons.csv` -- the flattened polygon geometry
  actually used for plotting: **every** path from the source SVG (bones,
  shading, and small detail paths), in original paint order
  (`order_index`), each with its own `fill`/`stroke`/`stroke_width`/
  `opacity` as authored. Only `role == "outline"` rows carry a `bone_name`
  (blank otherwise) -- shading and detail paths are background art with no
  bone identity, but they're what stops the skeleton looking flat, so
  `plot_skeleton_base()` and `skeletograph_heatmap()` both draw the full
  set. Bezier curves are subdivided into line segments here so
  `geom_polygon()` can draw them; y is already flipped so "up" means
  anatomically superior.
- `inst/extdata/bone_metadata.csv` -- one row per distinct `bone_name`
  (101 rows), with `bone_type` (drives which location vocabulary is valid)
  and `side` (`R`/`L`/`NA`).
- See `data-raw/` for the scripts that produced these three files from the
  source SVG, and for accessioning confidence notes.

## Accessioning confidence

Not every bone identity is equally certain -- the SVG wasn't built with
named layers, so identification was done visually, region by region.
`bone_accession.csv` and `bone_metadata.csv` both carry a `confidence`
column:

- **high** -- skull, girdle, and long bones, confirmed by shape.
- **medium** -- cervical vertebra level numbering, some skull suture
  fragments, sacrum/coccyx/pelvis subdivisions.
- **low** -- thoracic vertebra level numbering (assigned by sequential
  position down the column, not confirmed level-by-level), rib numbering
  beyond rib 9 per side, and two small lateral-thorax fragments
  (`rib_R_lower_margin_uncertain` / `rib_L_lower_margin_uncertain`) that
  could plausibly be ribs or a scapula border.
- **grouped** -- `hand_L/R`, `foot_L/R`, `teeth_upper/lower`, per your
  choice to group these rather than name each carpal/tarsal/tooth
  individually.

Worth a visual double-check pass on the `low`-confidence set before relying
on exact vertebra/rib numbers for anything level-specific.
