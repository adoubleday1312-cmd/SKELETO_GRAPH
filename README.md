# Skeletograph

This package is a tool for osteoarchaeologists, bioarchaeologists, anthropologists and archaeologists alike to plot skeletal observations onto a standard anterior-view human skeleton (currently a biological male). This package is inspired by the brilliant work of Maag et al. (2018) - the creator of gganatogram. This package differs from gganatogram as it is created through a bone accessioning scheme for palaeopathology, trauma, entheseal change, and taphonomic modification recording, with two separate plotting modes:

1. Individual observations (skeletograph_points()) -- plot specific lesions/marks at anatomically-described locations (e.g. "midshaft, lateral femur"), one point per observation, shaped by category.

2. Population-level heatmap (skeletograph_heatmap()) -- aggregate observations across many individuals into a per-bone average, coloured as a continuous gradient.


# An example using simulated data:
<img width="1794" height="1163" alt="image" src="https://github.com/user-attachments/assets/40cf05f7-bdef-4a5e-9e7d-3d40f1483f5e" />

You can remake this graph exactly using the "dummy" data spreadsheet available in the files, and following the rest of the scripting instructions below.


## Installation

This package is local to this repository only, and is not available on CRAN. Install the package from the source directory:

```r
install.packages("devtools")
library(devtools)
devtools::install()
```
# or, for iterative development:
```r
devtools::load_all()
Quick start
```
## 1. Individual observations
```r
library(skeletograph)
library(ggplot2)
```
> [!IMPORTANT]
> To plot the data manually for a single individual, use the below script:

First write the data frame for the observations - make sure that all of the columns match up, and if you're unsure of the terms for each of the bones, use the vocab function as shown below:

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

## Not sure what terms are valid for a given bone? Check before you build your data frame:
Vocab function:
skeletograph_vocabulary("femur_R")
#> $region:        proximal, proximal_third, midshaft, distal_third, distal
#> $side_position:  medial, central, lateral

skeletograph_vocabulary("cranium")
#> $region:        superior, central, inferior
#> $side_position:  right, central, left

skeletograph_vocabulary("hand_L")
#> $region:        central
#> $side_position:  central
hand_L, hand_R, foot_L, foot_R, teeth_upper, and teeth_lower are grouped regions -- the hand/foot bones and teeth, each carpal/metacarpal/phalanx/tooth is still its own separate polygon in the underlying SVG, but they only resolve to a single "central" location as one group. This was initially designed for ease when aligning the SVG to the anatomical regions and will be updated with specific element accessioning.

## 2. Population-level heatmap
Use this feature to plot the element based observations for multiple individuals onto the skeleton outline. 

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
Values can be anything you want aggregated -- a 0/1 presence flag (giving you a prevalence-rate heatmap once averaged), a severity score, or a raw count (pass aggregate_fun = sum). Bones with no rows in your data are shown in na_color (default light grey) rather than left blank.

If your data has more than one category and you don't pass category_filter, you get one small-multiple heatmap per category (facet_wrap(~category)) rather than categories being blended into a single number -- deliberately, since "average trauma" and "average entheseal change" per bone aren't comparable on one scale.

## Reading from a spreadsheet

While this package was initially written to be a manual input with each observation accessioned through a specific ID, the package now accepts the input and reading of an excel spreadsheet (.xlsx) or CSV (.csv). The spreadsheet needs to be clearly formatted following the conventions in the "dummy data" example provided. Be sure to use the specific terminology for the categories, as the program is term-sensitive.

>[!Important]
>To read from a spreadsheet, the spreadsheet must be in the current working directory, otherwise it will not be able to retrieve the data.

Below is an example using the simulated data as an example, but make sure to enter the name of the spreadsheet that you are using, and take note of sensitive components in the title (i.e. case, underscores, etc.) 

```r
data <- read_skeletograph_data("check.xlsx") #create the object for the data to then be called
data #check that the table is printing properly with all of the categories properly aligned

plot_skeleton_base() + skeletograph_points(data)
```

## Plotting differential diagnoses
The function Skeletograph_diagnoses() places observations on the skeleton in the same method/approach as the individual observations, but allows you to plot more certain observations which might have greater pathognomonic features (i.e. Tuberculosis, cribra orbital, sharp-force trauma etc). This function uses "modes" so you can plot all of the observations on one skeleton, and then have separate skeletons for the categories as shown below: 
<img width="2875" height="1163" alt="Palaeopath_modes_funciton" src="https://github.com/user-attachments/assets/8f299d09-118c-439a-846b-63ac525739ea" />

# Setup: 
The function is nested within the skeletograph_diagnoses.R file. Use the below code to load the function at the beginning of the session: 

```r
devtools::load_all()
source("skeletograph_diagnoses.R")
```

If you haven't already, you will need to install and call the patchwork package: 

```r
install.packages("patchwork")
library(patchwork)
```

# Calling your data: 
It is critical that each of the data rows contain the EXACT name, otherwise R cannot recognise the categories when producing the data frame. Use the following information to help construct your data: 


| Column | Meaning |
|---|---|
| `bone_name` | A bone from `list_bones()`, e.g. `thoracic_vertebra_T10` |
| `category` | `palaeopathology`, `trauma`, `entheseal_change`, `taphonomy` or `artefacts` |
| `region` | Proximal-distal / superior-inferior term for that bone (see `skeletograph_vocabulary()`) |
| `side_position` | Medial-lateral (or left-right) term for that bone |
| `diagnosis` | A diagnosis from `list_diagnoses()` that belongs to the row's `category` |

`surface` and `subtype` are optional and carried through unchanged.

`dummy_individual_all_categories.xlsx` is a worked example: one individual with every category. It is a demonstration sheet, not a plausible individual. Call the data from the sheet using the following code:

```r
obs <- read_skeletograph_data("dummy_individual_all_categories.xlsx")
```

### One skeleton

Add `skeletograph_diagnoses()` to `plot_skeleton_base()` with `+`:

```r
plot_skeleton_base() + skeletograph_diagnoses(obs)
```

The `mode` argument is the key to plotting the series of categories:

| `mode` | Draws | Shape shows | Colour shows |
|---|---|---|---|
| `"all"` (default) | Every category | Category | Diagnosis |
| `"palaeopathology"` | Palaeopathology rows only | Diagnostic group (infectious, general / non-specific, metabolic, arthropathy, congenital) | Diagnosis |
| `"trauma"` | Trauma rows only | Diagnosis | Diagnosis |
| `"taphonomy"` | Taphonomy rows only | Diagnosis | Diagnosis |
| `"entheseal_change"` | Entheseal change rows only | Entheseal change | Entheseal change |
| `"artefacts"` | Artefact rows only | Artefact | Artefact |

```r
plot_skeleton_base() + skeletograph_diagnoses(obs, mode = "palaeopathology")
plot_skeleton_base() + skeletograph_diagnoses(obs, mode = "trauma")
plot_skeleton_base() + skeletograph_diagnoses(obs, mode = "taphonomy")
```

Palaeopathology has the most diagnoses, so its colours are spread across the palaeopathology diagnoses only. To write each diagnosis next to its point as well, add `label = TRUE`:

```r
plot_skeleton_base() + skeletograph_diagnoses(obs, mode = "palaeopathology", label = TRUE)
```
When referring to only a single category, only that data is called on - be mindful when using this feature and be clear with terminology used. 

### One individual, one skeleton per category

```r
skeletograph_diagnosis_panels(obs)
```

This feature plots all of the data, but across multiple skeletons. One containing all of the data, and one skeleton for each of the categories. The order it does this is identical, and is always palaeopathology, trauma, entheseal change, taphonomy and artefacts (for now! comment if you would like other categories!, I'm always open to suggestions :) )


| Argument | What it does |
|---|---|
| `modes` | Which categories to draw, e.g. `c("palaeopathology", "trauma")`. Default: every category in `obs`. |
| `ncol` | Number of columns of skeletons. Default: all in one row. |
| `label` | `TRUE` writes each diagnosis next to its point. |
| `palette` | A MetBrewer palette name (default `"Hokusai1"`). |
| `size` | Point size (default `3`). |

```r
skeletograph_diagnosis_panels(obs, modes = c("palaeopathology", "trauma"), ncol = 2, label = TRUE)
```

Patchwork produces this as stitched item, so it can be saved like any other graph/image using the ggplot code:

```r
ggplot2::ggsave("individual_panels.png", skeletograph_diagnosis_panels(obs), width = 16, height = 9)
```

### Diagnoses

To call of the possible category as a list, use the following commands:

```r
list_diagnoses()               # the full list
list_diagnoses("taphonomy")    # one category
```

| Category | Group | Diagnoses |
|---|---|---|
| `palaeopathology` | infectious | tuberculosis (incl. Pott's disease), brucellosis, septic arthritis, leprosy, syphilis, yaws, bejel |
| | general / non-specific | new periosteal bone formation (NSPL / periostitis), erosive lesions, proliferative lesions |
| | metabolic | cribra orbitalia, porotic hyperostosis, linear enamel hypoplasia (LEH), scurvy, rickets, osteomalacia |
| | arthropathy | osteoarthritis, degenerative joint disease, Schmorl's nodes, psoriatic arthritis, rheumatoid arthritis |
| | congenital | achondroplasia, trisomy 21 (Down's syndrome), Klippel-Feil syndrome, scoliosis, congenital treponemal disease |
| `trauma` | | sharp-force trauma, blunt-force trauma |
| `entheseal_change` | | *(no subtypes)* |
| `taphonomy` | | erosion, abrasion, rodent gnawing, post-mortem modification |
| `artefacts` | | *(no subtypes)* |

Diagnoses are NOT case or grammar sensitive including capitals, spaces, hyphens and apostrophes, so `"Cribra orbitalia"`, `"cribra_orbitalia"` and `"sharp-force trauma"` all work. Some common aliases are also included for some conditions including`"Pott's disease"`, `"TB"`, `"LEH"`, `"Down's syndrome"`, `"NSPL"`, `"periostitis"`, `"dwarfism"` for the relevant conditions.

Entheseal change and artefacts don't have any further subdivisions so the `diagnosis` column doesn't need any further data and can be left blank. Every other category called upon must have a sub_division denoted in this column. 

### Colours

The colour palettes are drawn from the beautiful Met Brewer suite (by Blake Robert Mills), and uses **Signac** as the native palette by default. You can change the palette at any time with the palette argument below:

```r
plot_skeleton_base() + skeletograph_diagnoses(obs, palette = "Renoir")
```

`diagnosis_colors()` shows you each of the colours assigned for the diagnoses and you can pass your own named vector of colours (named by diagnosis) as `colors =`:

```r
diagnosis_colors()
diagnosis_colors("Renoir", category = "palaeopathology")
```

### Errors you might see

| Message | Cause |
|---|---|
| `` `data` has no `diagnosis` column `` | Add a `diagnosis` column (only entheseal change and artefact modes can do without one). |
| `Row n: category 'x' needs a diagnosis` | A blank `diagnosis` on a category that has subtypes. |
| `diagnosis value(s) not recognised: ...` | A typo or a diagnosis not in `list_diagnoses()`. |
| `diagnosis does not belong to the row's category` | For example, `tuberculosis` entered under `trauma`. |
| `region = ... is not valid for bone_name ...` | A location term that bone doesn't accept; check `skeletograph_vocabulary()`. |
| `skeletograph_diagnosis_panels() needs the patchwork package` | Run `install.packages("patchwork")`. |

In the single-category modes, "Row n" counts within that category's rows, not the whole sheet.

## Colour palettes (MetBrewer)

Both [skeletograph_points()] and [skeletograph_heatmap()] default to colours from Hokusai1, one of the palettes in the MetBrewer package by Blake Robert Mills -- palettes drawn from works held at the Metropolitan Museum of Art, this one after Katsushika Hokusai. All credit for the palette itself belongs there; skeletograph uses it as a default. MetBrewer is a Suggests dependency (install.packages("MetBrewer")) -- without it installed, both functions still work and fall back to a small built-in colour set.

Swap palettes with the palette argument on either function -- anything MetBrewer::met.brewer() accepts works ("Renoir", "Isfahan1", "Klimt", "VanGogh1", and more!):

```r
plot_skeleton_base() + skeletograph_points(observations, palette = "Renoir")
skeletograph_heatmap(pop_data, palette = "Isfahan1")
Or build your own named vector and skip the palette system entirely:

skeletograph_points(observations, colors = c(
  palaeopathology = "#1b9e77", trauma = "#d95f02",
  entheseal_change = "#7570b3", taphonomy = "#e7298a"
))
```

To see all of the colour combinations for the base categories (entheseal_change, palaeopathology, taphonomy and trauma) see the folder in the file directory titled "All colour combinations"
## Want to add osteobiographical information about your individual directly onto the plot? 

Use the below feature to include a box which has information about the individual
```r
install.packages("patchwork")
library("patchwork")
p <- plot_skeleton_base() + skeletograph_points(obs)

skeletograph_add_info(
  p,
  individual = 12,
  context = c("Grave 4", "Trench B", "Site X"),
  sex = "Probable female",
  age = "35-45 years",
  stature = "158 ± 4 cm"
)
```r
Make sure you change the details above to the details of your individual!


## Want to graph multiple skeletons together?

```r
install.packages("patchwork")
library("patchwork")
skeleton_1 <- plot_skeleton_base() + skeletograph_points(*insert data object here*)
skeleton_2 <- plot_skeleton_base() + skeletograph_points(*insert data object here*)
patchwork::wrap_plots(skeleton_1, skeleton_2, ncol=2)  #for skeletons aligned horizontally 
patchwork::wrap_plots(skeleton_1, skeleton_2, ncol=1) #for skeletons aligned vertically 
```


## The "surface" (anterior/posterior) limitation

The source artwork is a single anterior-view skeleton. An anterior vs. posterior distinction on a bone can't be shown as a different (x, y) position in a flat anterior projection -- both surfaces of, say, the femur project onto the same spot. resolve_location() and skeletograph_points() accept an optional surface column/argument and carry it through unchanged on the resolved data, so you can map it to a different aesthetic yourself if you need the distinction visually, e.g.:

skeletograph_points(observations) # surface carried through, unused

# or build the layer yourself with surface mapped to e.g. alpha/fill:
resolved <- resolve_location("femur_R", "midshaft", "lateral", surface = "posterior")
Adding a true posterior-view skeleton later is the natural way to resolve this properly -- see data-raw/ for how the current SVG was accessioned, which is the template for tracing/accessioning a posterior plate the same way.

# Feedback, features and requests: 
I am very open to feedback, and would love to hear your thoughts on the software - As this is the first R package that I have ever built, this world and the relevant processes, approaches, methods etc are quite foreign! Equally if there is a feature that doesn't currently exist that would benefit your specific niche, discipline, field or even general interest, please send me a message by using the Issues and Discussion section of the repository. 

# Citation

If you use this package in published research, please cite:

[AJ Doubleday] (2026). Skeletograph: Software for element based observation plotting for palaeopathology, trauma and taphonomy for R. https://github.com/adoubleday1312-cmd/Skeletograph

# License

MIT

# Bibliography and acknowledgements

This package was inspired by the monumental work of gganatogram which produces beautiful graphics for human and murine models. I wanted to create a package with the same elegance, accessibility and visual aesthetic which was tailored to the data and elements of the human body which are engaged with by bioarchaeologists and forensic anthropologists. Thank you to Maag et al. 2018 for publishing their work and making it completely open and accessible!

The image of the skeleton used in as the base for all plotted points was sourced from LadyofHats Mariana Ruiz Villarreal on Wikimedia Commons under the Public Domain License (accessible: https://commons.wikimedia.org/wiki/File:Human_skeleton_front_no-text_no-color.svg). Thank you for making your work publicly accessible in free to use.

Maag J (2018). "gganatogram: An R package for modular visualisation of anatograms and tissues based on ggplot2." f1000research. Version 1: Awaiting peer review, https://f1000research.com/articles/7-1576/v1.

Villarreal, L.M.R. (2007) human male skeleton. Available at: https://commons.wikimedia.org/wiki/File:Human_skeleton_front_no-text_no-color.svg (Accessed: September 17, 2026).

Anthropic (2026) Claude (Sonnet 4.6/5) [Large language model]. Available at: Claude AI (Accessed: 2 September 2026).

R version 4.6.1 -- "Happy Hop"

R Core Team (2026). R: A Language and Environment for Statistical Computing. R Foundation for Statistical Computing, Vienna, Austria. R Project.

# Transparency/disclosure:

This package is the intellectual property of A.J.Doubleday. 

I am a recently completed osteoarchaeology student who ADORES all things statistics, coding and computational biology. After discovering a hidden talent and absolute passion for DNA analysis (especially ancient DNA and disease analysis) and coding, I looked for ages to find an R package which replicates the customisability of GIS plotting with the anatomical specificity and correctness demanded by osteoarchaeology. As someone who has historically been very afraid and intimidated by AI, this project was an exercise in understanding the capacities and almost exposure therapy for using AI, while maintaining academic integrity and responsibility. The code for this package was written with the assistance of Claude.AI - model Sonnet 4.6 and 5. All AI generated material was thoroughly checked, tested and invigilated (including current external human alpha tests on separate, independent devices) to ensure accuracy. Full transparency about the use of AI in producing this package is maintained and should be acknowledged with any use of this package.


Please note that while the package was built using AI assistance, the process of entering data, graphing and use of the R/R Studio interface DOES NOT involve AI or any AI agent. While agents may be included in the process, this is the responsibility of the individual, not Skeletograph or A.J.Doubleday. The interface of this package does not involve, facilitate or endorse the uploading of any private, confidential, sensitive or any academic data to AI platforms. 
## Package contents / data provenance

inst/extdata/LadyofHats_skeleton_bone_accessioned.svg -- the source skeleton artwork (LadyofHats human skeleton illustration, anterior view), with every anatomically-identified path carrying data-bone-name and data-bone-confidence attributes.
inst/extdata/bone_accession.csv -- the raw per-SVG-path accessioning (path_id, bone_name, confidence, centroid, size). One row per SVG path (261 rows) -- several rows can share a bone_name.
inst/extdata/skeleton_polygons.csv -- the flattened polygon geometry actually used for plotting: every path from the source SVG (bones, shading, and small detail paths), in original paint order (order_index), each with its own fill/stroke/stroke_width/ opacity as authored. Only role == "outline" rows carry a bone_name (blank otherwise) -- shading and detail paths are background art with no bone identity, but they're what stops the skeleton looking flat, so plot_skeleton_base() and skeletograph_heatmap() both draw the full set. Bezier curves are subdivided into line segments here so geom_polygon() can draw them; y is already flipped so "up" means anatomically superior.
inst/extdata/bone_metadata.csv -- one row per distinct bone_name (101 rows), with bone_type (drives which location vocabulary is valid) and side (R/L/NA).
See data-raw/ for the scripts that produced these three files from the source SVG, and for accessioning confidence notes.

## Accessioning confidence

Not every bone identity is equally certain -- the SVG wasn't built with named layers, so identification was done visually, region by region. bone_accession.csv and bone_metadata.csv both carry a confidence column:

high -- skull, girdle, and long bones, confirmed by shape.
medium -- cervical vertebra level numbering, some skull suture fragments, sacrum/coccyx/pelvis subdivisions.
low -- thoracic vertebra level numbering (assigned by sequential position down the column, not confirmed level-by-level), rib numbering beyond rib 9 per side, and two small lateral-thorax fragments (rib_R_lower_margin_uncertain / rib_L_lower_margin_uncertain) that could plausibly be ribs or a scapula border.
grouped -- hand_L/R, foot_L/R, teeth_upper/lower, per your choice to group these rather than name each carpal/tarsal/tooth individually.

Worth a visual double-check pass on the low-confidence set before relying on exact vertebra/rib numbers for anything level-specific#> $side_position:  right, central, left

skeletograph_vocabulary("hand_L")
#> $region:        central
#> $side_position:  central




## A silly little extra: 
When trying to get the SVG organised which is used for the accessioning of all the bones into the co-ordinate system, I decided to see if ChatGPT could smooth out the image a little bit around the orbital cavities, and it produced this absolute masterpiece: 


<img width="271" height="626" alt="Screenshot 2026-10-08 at 6 42 58 pm" src="https://github.com/user-attachments/assets/26f52d40-8984-45ae-8b94-543023d27ce2" />



