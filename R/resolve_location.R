# Controlled-vocabulary location system ----------------------------------
#
# Design note: the source image is a single ANTERIOR-VIEW skeleton. That
# means an anterior-vs-posterior surface distinction cannot be expressed as a
# different (x, y) position -- both surfaces of a bone project to the same
# spot in a 2D anterior view. `surface` is therefore accepted and carried
# through as a data column (so you can map it to another aesthetic, e.g.
# point fill or alpha) but it never changes the resolved x/y. If a
# posterior-view skeleton is added later, this is the function to extend.

#' Depth-axis (proximal-distal / superior-inferior) vocabulary for a bone type
#' @keywords internal
.region_vocabulary <- function(bone_type) {
  if (bone_type == "long_bone") {
    c(proximal = 0.92, proximal_third = 0.75, midshaft = 0.50,
      distal_third = 0.25, distal = 0.08)
  } else if (bone_type == "grouped_region") {
    c(central = 0.5)
  } else {
    # skull_bone, flat_bone, rib, vertebra, sesamoid, irregular_bone
    c(superior = 0.85, central = 0.5, inferior = 0.15)
  }
}

#' y-band (as a fraction of the bone's own height) covered by a region term
#'
#' Used to take the medial-lateral width from just the LOCAL slice of the
#' bone at that region, rather than the bone's overall bounding box. Several
#' bones (e.g. a diagonally-drawn humerus, or a long bone assembled from a
#' separate proximal-head fragment plus a tapering shaft) have a much wider
#' overall bounding box than their width at any single height -- using the
#' whole-bone box for `side_position` could place a "lateral" point well
#' outside the drawn bone. Bands are non-overlapping and cover the full
#' 0 to 1 range, centred on the point values in [.region_vocabulary()].
#' @keywords internal
.region_band <- function(bone_type, region) {
  bands <- if (bone_type == "long_bone") {
    list(
      distal         = c(0.00, 0.16),
      distal_third   = c(0.16, 0.40),
      midshaft       = c(0.40, 0.60),
      proximal_third = c(0.60, 0.84),
      proximal       = c(0.84, 1.00)
    )
  } else if (bone_type == "grouped_region") {
    list(central = c(0.00, 1.00))
  } else {
    list(
      inferior = c(0.00, 0.30),
      central  = c(0.30, 0.70),
      superior = c(0.70, 1.00)
    )
  }
  unname(unlist(bands[[region]]))
}

#' Across-the-body-axis (medial-lateral, or left-right for midline bones)
#' vocabulary for a bone, given its type and side
#' @keywords internal
.side_vocabulary <- function(bone_type, side) {
  if (bone_type == "grouped_region") {
    return(c(central = 0.5))
  }
  if (!is.na(side) && side == "R") {
    # R-side bones sit left-of-midline in this anterior view: higher x is
    # medial (toward the body's own centre line), lower x is lateral.
    c(medial = 0.85, central = 0.5, lateral = 0.15)
  } else if (!is.na(side) && side == "L") {
    c(medial = 0.15, central = 0.5, lateral = 0.85)
  } else {
    # Midline bones with no inherent side (cranium, mandible, sternum,
    # sacrum, coccyx, teeth_upper/lower): use anatomical left/right directly.
    # Anatomical right = lower x, anatomical left = higher x, consistent
    # with the R/L convention used throughout the accessioning.
    c(right = 0.15, central = 0.5, left = 0.85)
  }
}

#' List the valid location vocabulary for a bone
#'
#' Since valid `region` and `side_position` terms depend on the bone's type
#' (a vertebra doesn't have a "midshaft"), use this to check what a given
#' bone accepts before calling [resolve_location()] or building an
#' observations table for [skeletograph_points()].
#'
#' @param bone_name character, e.g. `"femur_R"`. See [list_bones()].
#' @return a list with `bone_name`, `bone_type`, `region`, and
#'   `side_position` (the last two are character vectors of valid terms).
#' @examples
#' skeletograph_vocabulary("femur_R")
#' skeletograph_vocabulary("cranium")
#' skeletograph_vocabulary("hand_L")
#' @export
skeletograph_vocabulary <- function(bone_name) {
  meta <- .bone_meta(bone_name)
  bone_type <- meta$bone_type[1]
  side <- meta$side[1]
  list(
    bone_name = bone_name,
    bone_type = bone_type,
    region = names(.region_vocabulary(bone_type)),
    side_position = names(.side_vocabulary(bone_type, side))
  )
}

#' Resolve an anatomical location description to plot coordinates
#'
#' Turns a bone name plus a controlled-vocabulary description of *where* on
#' that bone (e.g. "midshaft", "lateral") into an (x, y) coordinate in the
#' skeleton diagram's coordinate space. This is the core translation step
#' used by [skeletograph_points()]; call it directly if you just want the
#' coordinates.
#'
#' @param bone_name character, must be one of [list_bones()], e.g. `"femur_R"`.
#' @param region character, a proximal-distal / superior-inferior term valid
#'   for that bone's type. Defaults to `"central"`. See
#'   [skeletograph_vocabulary()] for valid options per bone.
#' @param side_position character, a medial-lateral (or left-right, for
#'   midline bones) term valid for that bone's type. Defaults to `"central"`.
#' @param surface optional, `"anterior"` or `"posterior"` (or `NA`). Does
#'   **not** change the resolved position -- see Details -- but is returned
#'   so you can encode it another way (e.g. shape fill).
#' @return a one-row data.frame: `bone_name`, `x`, `y`, `surface`.
#' @details
#' The underlying image is a single anterior-view skeleton, so anterior and
#' posterior surfaces of a bone are not spatially distinguishable in this
#' version of the package.
#' @examples
#' resolve_location("femur_R", region = "midshaft", side_position = "lateral")
#' resolve_location("cranium", region = "superior", side_position = "left")
#' @export
resolve_location <- function(bone_name, region = "central", side_position = "central",
                              surface = NA) {
  meta <- .bone_meta(bone_name)
  bone_type <- meta$bone_type[1]
  side <- meta$side[1]

  region_map <- .region_vocabulary(bone_type)
  if (!region %in% names(region_map)) {
    stop(
      "region = '", region, "' is not valid for bone_name '", bone_name,
      "' (bone_type '", bone_type, "'). Valid options: ",
      paste(names(region_map), collapse = ", ")
    )
  }
  v_frac <- unname(region_map[region])

  side_map <- .side_vocabulary(bone_type, side)
  if (!side_position %in% names(side_map)) {
    stop(
      "side_position = '", side_position, "' is not valid for bone_name '", bone_name,
      "'. Valid options: ", paste(names(side_map), collapse = ", ")
    )
  }
  u_frac <- unname(side_map[side_position])

  poly <- .bone_polygon(bone_name)
  y_range <- range(poly$y)
  band <- .region_band(bone_type, region)
  y_lo <- y_range[1] + band[1] * diff(y_range)
  y_hi <- y_range[1] + band[2] * diff(y_range)

  # Take the medial-lateral width from just this region's local slice of the
  # bone, not the whole bone's bounding box -- see .region_band() for why.
  local_poly <- poly[poly$y >= y_lo & poly$y <= y_hi, ]
  if (nrow(local_poly) < 2) local_poly <- poly  # fallback: band too thin/empty
  x_range <- range(local_poly$x)

  data.frame(
    bone_name = bone_name,
    x = x_range[1] + u_frac * diff(x_range),
    y = y_range[1] + v_frac * diff(y_range),
    surface = surface,
    stringsAsFactors = FALSE
  )
}
