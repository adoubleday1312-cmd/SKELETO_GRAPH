# Internal data loading -------------------------------------------------
#
# The skeleton geometry and bone metadata are shipped as flat CSVs under
# inst/extdata (not as .rda objects) so they stay easy to inspect, diff, and
# regenerate from the source SVG without needing to rebuild the package.
# They're read once per session and cached in a private environment.

.skeletograph_env <- new.env(parent = emptyenv())

#' Load the flattened skeleton artwork (all paths, in paint order)
#'
#' One row per polygon vertex, for **every** path in the source SVG
#' (outline, shading and other-detail), not just the bone-identified ones.
#' Columns: `order_index` (position in the SVG = paint order), `path_id`,
#' `role` (`"outline"`, `"shading"`, `"other-detail"`), `bone_name` (only
#' `"outline"` paths have one; `NA` otherwise), `confidence`, `fill`,
#' `stroke`, `stroke_width`, `opacity`, `subpath_id`, `vertex_order`, `x`,
#' `y`. `fill`/`stroke` are the colours authored in the SVG, with `"none"`
#' converted to `NA`.
#'
#' Shading paths are interleaved with the outlines in the SVG (some sit
#' behind a bone, some on top of it), so always draw rows in `order_index`
#' order to reproduce the artwork.
#'
#' @return a data.frame, sorted in paint order
#' @keywords internal
.load_skeleton_polygons <- function() {
  if (is.null(.skeletograph_env$polygons)) {
    path <- system.file("extdata", "skeleton_polygons.csv", package = "skeletograph")
    if (path == "") stop("Could not find skeleton_polygons.csv in the installed package.")
    df <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
    df$fill[df$fill == "none"] <- NA
    df$stroke[df$stroke == "none"] <- NA
    df <- df[order(df$order_index, df$subpath_id, df$vertex_order), ]
    df$group_id <- paste(df$order_index, df$subpath_id, sep = "_")
    rownames(df) <- NULL
    .skeletograph_env$polygons <- df
  }
  .skeletograph_env$polygons
}

#' Load bone metadata (type + side classification per bone_name)
#'
#' Columns: `bone_name`, `bone_type` (one of `"long_bone"`, `"rib"`,
#' `"vertebra"`, `"skull_bone"`, `"flat_bone"`, `"sesamoid"`,
#' `"irregular_bone"`, `"grouped_region"`), `side` (`"R"`, `"L"`, or `NA` for
#' midline/grouped elements), and `confidence` (accessioning confidence
#' carried over from the source SVG: `"high"`, `"medium"`, `"low"`, or
#' `"grouped"`).
#'
#' @return a data.frame
#' @keywords internal
.load_bone_metadata <- function() {
  if (is.null(.skeletograph_env$metadata)) {
    path <- system.file("extdata", "bone_metadata.csv", package = "skeletograph")
    if (path == "") stop("Could not find bone_metadata.csv in the installed package.")
    df <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
    .skeletograph_env$metadata <- df
  }
  .skeletograph_env$metadata
}

#' Get the polygon geometry for a single bone
#' @keywords internal
.bone_polygon <- function(bone_name) {
  polys <- .load_skeleton_polygons()
  sub <- polys[!is.na(polys$bone_name) & polys$bone_name == bone_name, ]
  if (nrow(sub) == 0) {
    stop(
      "No polygon geometry found for bone_name '", bone_name, "'. ",
      "See skeletograph::list_bones() for valid names."
    )
  }
  sub
}

#' Get the metadata row for a single bone
#' @keywords internal
.bone_meta <- function(bone_name) {
  metadata <- .load_bone_metadata()
  row <- metadata[metadata$bone_name == bone_name, ]
  if (nrow(row) == 0) {
    stop(
      "Unknown bone_name '", bone_name, "'. ",
      "See skeletograph::list_bones() for valid names."
    )
  }
  row
}

#' List every valid bone_name known to the package
#'
#' @return a character vector of bone names, e.g. `"femur_R"`, `"cranium"`,
#'   `"hand_L"`.
#' @export
list_bones <- function() {
  sort(.load_bone_metadata()$bone_name)
}
