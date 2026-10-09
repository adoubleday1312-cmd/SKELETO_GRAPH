# skeletograph_diagnoses.R -----------------------------------------------
#
# Self-contained add-on: draws individual observations coloured by their
# concrete DIAGNOSIS (the subtypes within each recording category), in
# "modes" -- one for each base category -- and can lay a single individual
# out as several skeletons side by side, one skeleton per category.
#
#   skeletograph_diagnoses(data, mode = "all")      one skeleton, every category
#   skeletograph_diagnoses(data, mode = "palaeopathology")   (or "trauma",
#                                    "entheseal_change", "taphonomy", "artefacts")
#   skeletograph_diagnosis_panels(data)             one skeleton per category
#   list_diagnoses(), diagnosis_colors()            helpers
#
# Separate from the individual-observations and population-heatmap functions:
# it needs nothing from them and changes nothing in them. It only calls
# resolve_location(), category_shapes() and plot_skeleton_base(), which the
# package already exports. The multi-skeleton function also needs the
# patchwork package: install.packages("patchwork")
#
# Two ways to use it:
#   (a) Console, any session:   devtools::load_all(); source("skeletograph_diagnoses.R")
#   (b) Part of the package:    copy to R/skeletograph_diagnoses.R, then
#         - add "diagnosis", "shape_key", "dx_label" to utils::globalVariables() in R/zzz.R
#         - add export(skeletograph_diagnoses), export(skeletograph_diagnosis_panels),
#           export(list_diagnoses), export(diagnosis_colors) to NAMESPACE
#           (or run devtools::document())
#         - add grDevices to Imports, and patchwork to Suggests, in DESCRIPTION

# Diagnosis hierarchy ---------------------------------------------------
#
# One entry per concrete diagnosis, grouped within its recording category.
# `diagnosis` is the canonical value stored/plotted; `aliases` are other
# spellings accepted in a spreadsheet (matched case-insensitively, with
# spaces/hyphens/apostrophes ignored -- see .normalise_key()).
#
# Categories without subtypes (entheseal_change, artefacts) have a single
# default entry, so the `diagnosis` column can simply be left blank for them.

.dx <- function(category, group, diagnosis, label, aliases = character(0)) {
  list(category = category, group = group, diagnosis = diagnosis,
       label = label, aliases = aliases)
}

.diagnosis_hierarchy <- function() {
  pp <- "palaeopathology"
  list(
    # infectious markers
    .dx(pp, "infectious", "tuberculosis", "Tuberculosis (incl. Pott's disease)",
        c("potts_disease", "mycobacterium_tuberculosis", "tb")),
    .dx(pp, "infectious", "brucellosis", "Brucellosis"),
    .dx(pp, "infectious", "septic_arthritis", "Septic arthritis"),
    .dx(pp, "infectious", "leprosy", "Leprosy"),
    .dx(pp, "infectious", "syphilis", "Syphilis (treponemal)"),
    .dx(pp, "infectious", "yaws", "Yaws (treponemal)"),
    .dx(pp, "infectious", "bejel", "Bejel (treponemal)"),
    # general / non-specific
    .dx(pp, "general_non_specific", "new_periosteal_bone_formation",
        "New periosteal bone formation (NSPL / periostitis)",
        c("nspl", "periostitis")),
    .dx(pp, "general_non_specific", "erosive_lesions", "Erosive lesions"),
    .dx(pp, "general_non_specific", "proliferative_lesions", "Proliferative lesions"),
    # metabolic indicators
    .dx(pp, "metabolic", "cribra_orbitalia", "Cribra orbitalia"),
    .dx(pp, "metabolic", "porotic_hyperostosis", "Porotic hyperostosis"),
    .dx(pp, "metabolic", "linear_enamel_hypoplasia", "Linear enamel hypoplasia (LEH)",
        "leh"),
    .dx(pp, "metabolic", "scurvy", "Scurvy"),
    .dx(pp, "metabolic", "rickets", "Rickets"),
    .dx(pp, "metabolic", "osteomalacia", "Osteomalacia"),
    # arthropathies
    .dx(pp, "arthropathy", "osteoarthritis", "Osteoarthritis"),
    .dx(pp, "arthropathy", "degenerative_joint_disease", "Degenerative joint disease",
        "djd"),
    .dx(pp, "arthropathy", "schmorls_nodes", "Schmorl's nodes"),
    .dx(pp, "arthropathy", "psoriatic_arthritis", "Psoriatic arthritis"),
    .dx(pp, "arthropathy", "rheumatoid_arthritis", "Rheumatoid arthritis"),
    # congenital conditions
    .dx(pp, "congenital", "achondroplasia", "Achondroplasia (dwarfism)", "dwarfism"),
    .dx(pp, "congenital", "trisomy_21", "Trisomy 21 (Down's syndrome)",
        c("downs_syndrome", "down_syndrome")),
    .dx(pp, "congenital", "klippel_feil_syndrome", "Klippel-Feil syndrome"),
    .dx(pp, "congenital", "scoliosis", "Scoliosis"),
    .dx(pp, "congenital", "congenital_treponemal_disease",
        "Congenital treponemal disease"),
    # trauma
    .dx("trauma", "trauma", "sharp_force_trauma", "Sharp-force trauma", "sharp_force"),
    .dx("trauma", "trauma", "blunt_force_trauma", "Blunt-force trauma", "blunt_force"),
    # entheseal change (no subtypes)
    .dx("entheseal_change", "entheseal_change", "entheseal_change", "Entheseal change"),
    # taphonomy
    .dx("taphonomy", "taphonomy", "erosion", "Erosion"),
    .dx("taphonomy", "taphonomy", "abrasion", "Abrasion"),
    .dx("taphonomy", "taphonomy", "rodent_gnawing", "Rodent gnawing"),
    .dx("taphonomy", "taphonomy", "post_mortem_modification",
        "Post-mortem modification", "postmortem_modification"),
    # artefacts (no subtypes)
    .dx("artefacts", "artefacts", "artefact", "Artefact", "artefacts")
  )
}

.diagnosis_table <- function() {
  h <- .diagnosis_hierarchy()
  data.frame(
    category  = vapply(h, function(d) d$category,  character(1)),
    group     = vapply(h, function(d) d$group,     character(1)),
    diagnosis = vapply(h, function(d) d$diagnosis, character(1)),
    label     = vapply(h, function(d) d$label,     character(1)),
    stringsAsFactors = FALSE
  )
}

# Lower-case, drop apostrophes, and collapse anything that isn't a letter or
# digit to a single underscore, so "Pott's disease", "sharp-force trauma" and
# "Sharp force trauma" all compare equal to their snake_case form.
.normalise_key <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("['\u2019]", "", x)
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_+|_+$", "", x)
}

# Named character vector: normalised spelling (canonical name or alias) -> canonical name
.diagnosis_lookup <- function() {
  h <- .diagnosis_hierarchy()
  keys <- unlist(lapply(h, function(d) c(d$diagnosis, d$aliases)))
  vals <- unlist(lapply(h, function(d) rep(d$diagnosis, 1 + length(d$aliases))))
  stats::setNames(vals, .normalise_key(keys))
}

#' Check diagnosis values against the hierarchy and return canonical names
#'
#' Blank/`NA` diagnoses are filled in only for categories that have a single
#' default entry (entheseal change, artefacts); for any other category a
#' blank is an error, as is a diagnosis that belongs to a different category.
#' @param diagnosis character vector of diagnoses as typed (aliases allowed).
#' @param category character vector of categories, same length.
#' @return character vector of canonical diagnosis names.
#' @keywords internal
.standardise_diagnosis <- function(diagnosis, category) {
  tbl <- .diagnosis_table()
  lookup <- .diagnosis_lookup()
  diagnosis <- as.character(diagnosis)
  category <- as.character(category)

  if (anyNA(category)) {
    stop("`category` has missing values in row(s): ",
         paste(which(is.na(category)), collapse = ", "))
  }
  unknown_category <- setdiff(unique(category), tbl$category)
  if (length(unknown_category) > 0) {
    stop("category value(s) not recognised: ", paste(unknown_category, collapse = ", "),
         ". Valid categories: ", paste(unique(tbl$category), collapse = ", "))
  }

  key <- .normalise_key(diagnosis)
  blank <- is.na(key) | key == ""
  canonical <- unname(lookup[key])
  canonical[blank] <- NA_character_

  for (i in which(blank)) {
    options <- tbl$diagnosis[tbl$category == category[i]]
    if (length(options) == 1) {
      canonical[i] <- options
    } else {
      stop(
        "Row ", i, ": category '", category[i], "' needs a `diagnosis`. Valid options: ",
        paste(options, collapse = ", ")
      )
    }
  }

  unknown <- which(is.na(canonical))
  if (length(unknown) > 0) {
    stop(
      "diagnosis value(s) not recognised: ", paste(unique(diagnosis[unknown]), collapse = ", "),
      ". See list_diagnoses() for valid values."
    )
  }

  expected <- tbl$category[match(canonical, tbl$diagnosis)]
  bad <- which(expected != category)
  if (length(bad) > 0) {
    stop(
      "Row(s) ", paste(bad, collapse = ", "), ": diagnosis does not belong to the row's category ",
      "(e.g. '", canonical[bad[1]], "' is a ", expected[bad[1]], " diagnosis, but category is '",
      category[bad[1]], "')."
    )
  }
  canonical
}

#' List every diagnosis the package knows about
#'
#' The hierarchy used by skeletograph_diagnoses(): each diagnosis belongs
#' to a `group` (e.g. infectious, metabolic, arthropathy) within a recording
#' `category`. `diagnosis` is the canonical value; a spreadsheet may also use
#' common aliases (e.g. `"Pott's disease"` for `tuberculosis`, `"LEH"` for
#' `linear_enamel_hypoplasia`, `"Down's syndrome"` for `trisomy_21`) --
#' matching ignores case, spaces, hyphens and apostrophes.
#'
#' Entheseal change and artefacts have no subtypes, so they have one default
#' entry each and their `diagnosis` can be left blank.
#'
#' @param category optional character vector to filter to one or more
#'   categories, e.g. `"taphonomy"`.
#' @return a data.frame with columns `category`, `group`, `diagnosis`, `label`.
#' @examples
#' list_diagnoses()
#' list_diagnoses("trauma")
#' @export
list_diagnoses <- function(category = NULL) {
  tbl <- .diagnosis_table()
  if (!is.null(category)) {
    unknown <- setdiff(category, unique(tbl$category))
    if (length(unknown) > 0) {
      stop("Unknown category: ", paste(unknown, collapse = ", "),
           ". Valid categories: ", paste(unique(tbl$category), collapse = ", "))
    }
    tbl <- tbl[tbl$category %in% category, ]
  }
  rownames(tbl) <- NULL
  tbl
}

# Modes ------------------------------------------------------------------

.diagnosis_modes <- function() {
  c("all", "palaeopathology", "trauma", "entheseal_change", "taphonomy", "artefacts")
}

# Palaeopathology has 26 diagnoses in five groups, so in that mode SHAPE
# shows the diagnostic group and COLOUR shows the diagnosis.
.group_labels <- function() {
  c(infectious = "Infectious",
    general_non_specific = "General / non-specific",
    metabolic = "Metabolic",
    arthropathy = "Arthropathy",
    congenital = "Congenital")
}

.palaeo_group_shapes <- function() {
  c(infectious = 16, general_non_specific = 15, metabolic = 17,
    arthropathy = 18, congenital = 8)
}

# The other modes have few enough diagnoses that shape AND colour both show
# the diagnosis (and share one legend).
.diagnosis_shapes <- function() {
  c(sharp_force_trauma = 17, blunt_force_trauma = 15,
    entheseal_change = 15,
    erosion = 16, abrasion = 15, rodent_gnawing = 17, post_mortem_modification = 18,
    artefact = 8)
}

# Discrete MetBrewer colours for n items. MetBrewer picks its most
# distinguishable subset when n is smaller than the palette. When n is larger
# than the palette, the palette is repeated in a darker and then a lighter
# shade, so colours are never interpolated into near-identical neighbours.
.met_discrete <- function(palette, n) {
  base <- NULL
  seen_ok <- FALSE
  for (k in seq_len(40)) {
    got <- tryCatch(
      as.character(MetBrewer::met.brewer(palette, k, type = "discrete")),
      error = function(e) NULL
    )
    if (!is.null(got)) {
      base <- got
      seen_ok <- TRUE
    } else if (seen_ok) {
      break
    }
  }
  if (is.null(base)) {
    stop("MetBrewer palette '", palette, "' not found. Check the spelling against the ",
         "MetBrewer documentation.")
  }
  if (n <= length(base)) {
    out <- tryCatch(
      as.character(MetBrewer::met.brewer(palette, n, type = "discrete")),
      error = function(e) NULL
    )
    if (is.null(out) || length(out) != n) out <- base[seq_len(n)]
    return(out)
  }
  rgbm <- grDevices::col2rgb(base) / 255
  out <- character(0)
  cycle <- 0
  while (length(out) < n) {
    shade <- switch(cycle %% 3 + 1,
      rgbm,                              # original
      rgbm * 0.6,                        # darker
      rgbm + (1 - rgbm) * 0.55           # lighter
    )
    out <- c(out, grDevices::rgb(shade[1, ], shade[2, ], shade[3, ]))
    cycle <- cycle + 1
  }
  out[seq_len(n)]
}

#' Colours for individual diagnoses
#'
#' Gives each diagnosis its own clearly different colour from a discrete
#' (qualitative) MetBrewer palette -- default **Signac**, which has 14 distinct
#' colours (MetBrewer is by Blake Robert Mills; palettes are inspired by works
#' at the Metropolitan Museum of Art). Colours are *not* interpolated along a
#' gradient, so neighbouring diagnoses never end up with near-identical colours.
#'
#' Which diagnoses get colours:
#' \itemize{
#'   \item with `diagnoses` given, just those (the plotting functions use this
#'     so a plot only spends colours on the diagnoses it actually shows);
#'   \item otherwise every diagnosis in `category`, or in the whole hierarchy
#'     if `category` is `NULL`.
#' }
#' If there are more diagnoses than colours in the palette, the palette is
#' repeated in a darker and then a lighter shade. Palettes with more colours
#' (Signac and Tam have 14) keep that rarer. Without MetBrewer installed, falls
#' back to base R's `Polychrome 36` palette.
#'
#' Colours depend on the set of diagnoses asked for, so the same diagnosis can
#' be a different colour in two plots that show different diagnoses. To keep
#' colours fixed across several plots, build one vector and pass it to
#' `colors =`, e.g. `diagnosis_colors(diagnoses = c("tuberculosis", "leprosy"))`.
#'
#' @param palette name of a MetBrewer palette. Default `"Signac"`.
#' @param category optional single category, e.g. `"palaeopathology"`.
#' @param diagnoses optional character vector of diagnoses (aliases allowed).
#' @return a named character vector of hex colours, named by diagnosis, in
#'   the hierarchy's order (see [list_diagnoses()]).
#' @examples
#' \dontrun{
#' diagnosis_colors(category = "taphonomy")
#' diagnosis_colors("Tam", diagnoses = c("Pott's disease", "leprosy", "scurvy"))
#' }
#' @export
diagnosis_colors <- function(palette = "Signac", category = NULL, diagnoses = NULL) {
  tbl <- .diagnosis_table()
  if (!is.null(category)) {
    if (length(category) != 1 || !category %in% unique(tbl$category)) {
      stop("`category` must be one of: ", paste(unique(tbl$category), collapse = ", "))
    }
    tbl <- tbl[tbl$category == category, ]
  }
  if (!is.null(diagnoses)) {
    canon <- unname(.diagnosis_lookup()[.normalise_key(diagnoses)])
    if (anyNA(canon)) {
      stop("diagnosis value(s) not recognised: ",
           paste(unique(diagnoses[is.na(canon)]), collapse = ", "),
           ". See list_diagnoses() for valid values.")
    }
    tbl <- .diagnosis_table()
    tbl <- tbl[tbl$diagnosis %in% canon, ]
  }
  dx <- tbl$diagnosis
  n <- length(dx)
  if (n == 0) return(stats::setNames(character(0), character(0)))
  cols <- if (requireNamespace("MetBrewer", quietly = TRUE)) {
    .met_discrete(palette, n)
  } else if (getRversion() >= "4.0.0") {
    unname(grDevices::palette.colors(n, palette = "Polychrome 36"))
  } else {
    grDevices::hcl.colors(n, palette = "Dark 3")
  }
  stats::setNames(as.character(cols), dx)
}

#' Plot individual observations coloured by concrete diagnosis
#'
#' Places each row at its anatomically-described location (via
#' [resolve_location()]) and colours it by its specific diagnosis. The
#' `mode` chooses what is drawn and what shape means:
#'
#' \describe{
#'   \item{`"all"` (default)}{every category on one skeleton. Shape =
#'     category, colour = diagnosis.}
#'   \item{`"palaeopathology"`}{palaeopathology rows only. Shape = diagnostic
#'     group (infectious, general / non-specific, metabolic, arthropathy,
#'     congenital), colour = diagnosis.}
#'   \item{`"trauma"`, `"taphonomy"`}{that category only. Shape and colour
#'     both = diagnosis (one shared legend).}
#'   \item{`"entheseal_change"`, `"artefacts"`}{that category only. These
#'     have no subtypes, so the `diagnosis` column can be left out or blank.}
#' }
#'
#' Add the result to `plot_skeleton_base()` with `+`. To see one individual
#' as one skeleton per category, use [skeletograph_diagnosis_panels()].
#'
#' @param data a data.frame with columns `bone_name`, `category`, `region`,
#'   `side_position` (as for the individual-observations function) plus
#'   `diagnosis` -- a diagnosis from [list_diagnoses()] (aliases such as
#'   `"Pott's disease"` or `"LEH"` are accepted) belonging to the row's
#'   `category`. Optional `surface` and `subtype` columns are carried through.
#'   In a single-category mode, only that category's rows are used (so
#'   "Row n" in an error counts within those rows).
#' @param mode one of `"all"`, `"palaeopathology"`, `"trauma"`,
#'   `"entheseal_change"`, `"taphonomy"`, `"artefacts"`.
#' @param shapes named vector of shapes. Names are categories in `"all"` mode,
#'   groups in `"palaeopathology"` mode, diagnoses otherwise. Default depends
#'   on the mode.
#' @param colors named vector of colours by *diagnosis*. Default
#'   [diagnosis_colors()] for the diagnoses present in the plot: one clearly
#'   different colour each, not a gradient.
#' @param palette shorthand for a discrete MetBrewer palette for the default
#'   `colors`; ignored if you supply `colors`. Default `"Signac"`.
#' @param size point size. Default `3`.
#' @param label if `TRUE`, also write each diagnosis next to its point.
#'   Handy in palaeopathology mode, which has the most diagnoses.
#' @return a list of ggplot2 layers addable to a plot with `+`.
#' @examples
#' \dontrun{
#' obs <- read_skeletograph_data("dummy_individual_all_categories.xlsx")
#' plot_skeleton_base() + skeletograph_diagnoses(obs)
#' plot_skeleton_base() + skeletograph_diagnoses(obs, mode = "palaeopathology", label = TRUE)
#' plot_skeleton_base() + skeletograph_diagnoses(obs, mode = "taphonomy")
#' }
#' @export
skeletograph_diagnoses <- function(data, mode = "all", shapes = NULL, colors = NULL,
                                   palette = "Signac", size = 3, label = FALSE) {
  mode <- match.arg(mode, .diagnosis_modes())

  required <- c("bone_name", "category", "region", "side_position")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    stop("`data` is missing required column(s): ", paste(missing_cols, collapse = ", "))
  }
  if (!"diagnosis" %in% names(data)) {
    if (mode %in% c("entheseal_change", "artefacts")) {
      data$diagnosis <- NA_character_  # these categories have no subtypes
    } else {
      stop(
        "`data` has no `diagnosis` column. Add one (see list_diagnoses()), or use ",
        "your individual-observations function if you only have categories."
      )
    }
  }
  if (!"surface" %in% names(data)) data$surface <- NA
  if (!"subtype" %in% names(data)) data$subtype <- NA

  if (mode != "all") {
    data <- data[!is.na(data$category) & data$category == mode, , drop = FALSE]
    if (nrow(data) == 0) stop("No rows with category '", mode, "' in `data`.")
  }

  data$diagnosis <- .standardise_diagnosis(data$diagnosis, data$category)
  tbl <- .diagnosis_table()
  labels <- stats::setNames(tbl$label, tbl$diagnosis)

  # Uses only exported skeletograph functions (resolve_location), so this file
  # works without touching the observations or population code.
  resolved <- do.call(rbind, lapply(seq_len(nrow(data)), function(i) {
    loc <- resolve_location(
      bone_name     = data$bone_name[i],
      region        = data$region[i],
      side_position = data$side_position[i],
      surface       = data$surface[i]
    )
    loc$category  <- data$category[i]
    loc$subtype   <- data$subtype[i]
    loc$diagnosis <- data$diagnosis[i]
    loc$group     <- tbl$group[match(data$diagnosis[i], tbl$diagnosis)]
    loc
  }))
  resolved$dx_label <- unname(labels[resolved$diagnosis])

  # Colours: by diagnosis, in every mode ----------------------------------
  # Colours are spent only on the diagnoses actually present in this plot, so
  # they are as different from one another as the palette allows.
  present <- tbl$diagnosis[tbl$diagnosis %in% resolved$diagnosis]  # hierarchy order
  if (is.null(colors)) colors <- diagnosis_colors(palette, diagnoses = present)
  unknown_color_dx <- setdiff(present, names(colors))
  if (length(unknown_color_dx) > 0) {
    stop(
      "diagnosis value(s) not found in `colors`: ", paste(unknown_color_dx, collapse = ", "),
      ". `colors` must cover every diagnosis shown in the plot. Build one with, e.g., ",
      "diagnosis_colors(diagnoses = <all the diagnoses you want to plot>), ",
      "or leave `colors` out to pick colours automatically."
    )
  }
  dx_labels <- unname(labels[present])

  # Shapes: what they show depends on the mode ------------------------------
  merged_legend <- FALSE
  if (mode == "all") {
    resolved$shape_key <- resolved$category
    if (is.null(shapes)) shapes <- category_shapes()
    shape_title <- "Category"
    key_order <- names(shapes)
    key_labels <- function(k) k
  } else if (mode == "palaeopathology") {
    resolved$shape_key <- resolved$group
    if (is.null(shapes)) shapes <- .palaeo_group_shapes()
    shape_title <- "Group"
    key_order <- names(.group_labels())
    key_labels <- function(k) unname(.group_labels()[k])
  } else {
    resolved$shape_key <- resolved$diagnosis
    if (is.null(shapes)) shapes <- .diagnosis_shapes()
    shape_title <- "Diagnosis"
    key_order <- tbl$diagnosis
    key_labels <- function(k) unname(labels[k])
    merged_legend <- TRUE
  }
  unknown_shape_key <- setdiff(unique(resolved$shape_key), names(shapes))
  if (length(unknown_shape_key) > 0) {
    stop(
      "value(s) not found in `shapes`: ", paste(unknown_shape_key, collapse = ", "),
      ". Pass a `shapes` vector that includes them, e.g. ",
      "shapes = c(<defaults>, ", unknown_shape_key[1], " = 8)"
    )
  }
  key_present <- key_order[key_order %in% resolved$shape_key]

  resolved$diagnosis <- factor(resolved$diagnosis, levels = present)

  layers <- list(
    ggplot2::geom_point(
      data = resolved,
      mapping = ggplot2::aes(x = x, y = y, shape = shape_key, color = diagnosis),
      size = size,
      inherit.aes = FALSE
    ),
    ggplot2::scale_shape_manual(
      name = shape_title, values = shapes,
      limits = key_present, labels = key_labels(key_present)
    ),
    ggplot2::scale_color_manual(
      name = "Diagnosis", values = colors,
      limits = present, labels = dx_labels
    )
  )
  if (!merged_legend) {
    layers <- c(layers, list(ggplot2::guides(
      shape  = ggplot2::guide_legend(order = 1),
      colour = ggplot2::guide_legend(order = 2, override.aes = list(shape = 16))
    )))
  }
  if (isTRUE(label)) {
    layers <- c(layers, list(ggplot2::geom_text(
      data = resolved,
      mapping = ggplot2::aes(x = x, y = y, label = dx_label),
      inherit.aes = FALSE, size = 2.3, hjust = 0, nudge_x = 8,
      check_overlap = TRUE, show.legend = FALSE
    )))
  }
  layers
}

#' One individual, one skeleton per category
#'
#' Draws the same individual several times side by side -- one skeleton for
#' each recording category present in `data` -- each in its own
#' [skeletograph_diagnoses()] mode, with its own legend. Needs the patchwork
#' package (`install.packages("patchwork")`).
#'
#' @param data as for [skeletograph_diagnoses()].
#' @param modes optional character vector choosing which categories to draw
#'   (and in what order is fixed: palaeopathology, trauma, entheseal change,
#'   taphonomy, artefacts). Default: every category present in `data`.
#' @param ncol number of columns of skeletons. Default: all in one row.
#' @param colors,palette,size,label passed to [skeletograph_diagnoses()].
#' @return a patchwork object (prints as one figure; save it with
#'   `ggplot2::ggsave()`).
#' @examples
#' \dontrun{
#' obs <- read_skeletograph_data("dummy_individual_all_categories.xlsx")
#' skeletograph_diagnosis_panels(obs)
#' skeletograph_diagnosis_panels(obs, modes = c("palaeopathology", "trauma"), label = TRUE)
#' }
#' @export
skeletograph_diagnosis_panels <- function(data, modes = NULL, ncol = NULL, colors = NULL,
                                          palette = "Signac", size = 3, label = FALSE) {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("skeletograph_diagnosis_panels() needs the patchwork package. Install it with:\n",
         '  install.packages("patchwork")')
  }
  if (!"category" %in% names(data)) {
    stop("`data` is missing required column(s): category")
  }
  cats <- .diagnosis_modes()[-1]
  chosen <- cats[cats %in% data$category]
  if (!is.null(modes)) {
    bad <- setdiff(modes, cats)
    if (length(bad) > 0) {
      stop("modes not recognised: ", paste(bad, collapse = ", "),
           ". Valid: ", paste(cats, collapse = ", "))
    }
    chosen <- chosen[chosen %in% modes]
  }
  if (length(chosen) == 0) stop("No rows in `data` match the requested modes.")

  titles <- c(palaeopathology = "Palaeopathology", trauma = "Trauma",
              entheseal_change = "Entheseal change", taphonomy = "Taphonomy",
              artefacts = "Artefacts")
  plots <- lapply(chosen, function(m) {
    plot_skeleton_base() +
      skeletograph_diagnoses(data, mode = m, colors = colors, palette = palette,
                             size = size, label = label) +
      ggplot2::labs(title = titles[[m]])
  })
  if (is.null(ncol)) ncol <- length(plots)
  patchwork::wrap_plots(plots, ncol = ncol)
}
