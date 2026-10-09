#' Default shapes for the four recording categories
#'
#' Exported (not just internal) so you can reuse or extend it, e.g.
#' `scale_shape_manual(values = c(skeletograph::category_shapes(), my_new_category = 8))`.
#'
#' @return a named integer vector of ggplot2 point shapes.
#' @examples
#' category_shapes()
#' @export
category_shapes <- function() {
  c(
    palaeopathology   = 16, # filled circle
    trauma            = 17, # filled triangle
    entheseal_change  = 15, # filled square
    taphonomy         = 18, # filled diamond
    artefacts         = 8   # star
  )
}

#' Plot individual observations at specific anatomical locations
#'
#' Takes a table of individual observations -- one row per lesion, fracture,
#' entheseal change, or taphonomic mark -- and returns ggplot2 layers (a
#' point layer plus shape and colour scales) that place each one at its
#' anatomically-described location on the skeleton, shaped *and* coloured
#' by category.
#'
#' Add the result to [plot_skeleton_base()] with `+`.
#'
#' @param data a data.frame with required columns:
#'   \describe{
#'     \item{bone_name}{e.g. `"femur_R"`. See [list_bones()].}
#'     \item{category}{one of `names(category_shapes())` by default --
#'       `"palaeopathology"`, `"trauma"`, `"entheseal_change"`, or
#'       `"taphonomy"`, or `"artefacts"` -- unless you pass your own `shapes`/`colors`.}
#'     \item{region}{proximal-distal / superior-inferior location term.
#'       See [skeletograph_vocabulary()] for valid terms per bone.}
#'     \item{side_position}{medial-lateral (or left-right) location term.}
#'   }
#'   Optional columns:
#'   \describe{
#'     \item{subtype}{free-text subtype within a category (e.g. a specific
#'       trauma type). Not yet mapped to an aesthetic -- carried through on
#'       the resolved data so a future version can use it (e.g. for
#'       faceting, or a second shape split within category).}
#'     \item{surface}{`"anterior"` or `"posterior"`. Does not change plot
#'       position (see [resolve_location()]) but is carried through so you
#'       can map it to another aesthetic yourself, e.g.
#'       `+ ggplot2::aes(alpha = surface)`.}
#'   }
#' @param shapes named vector of shape values, passed to
#'   `scale_shape_manual(values = shapes)`. Defaults to [category_shapes()].
#' @param colors named vector of colours, passed to
#'   `scale_color_manual(values = colors)`. Defaults to [category_colors()],
#'   which draws from the **Hokusai1** palette (see that function's docs for
#'   credit and how to switch palettes) -- pass `palette = "SomeOtherName"`
#'   to use a different MetBrewer palette without building the vector
#'   yourself, e.g. `skeletograph_points(data, palette = "Renoir")`.
#' @param palette shorthand for choosing a MetBrewer palette for the default
#'   `colors`; ignored if you supply `colors` directly. Default `"Hokusai1"`.
#' @param size point size. Default `3`.
#' @return a list of ggplot2 layers (`geom_point`, `scale_shape_manual`,
#'   `scale_color_manual`), addable to a plot with `+`.
#' @examples
#' \dontrun{
#' observations <- data.frame(
#'   bone_name = c("femur_R", "tibia_L"),
#'   category = c("trauma", "palaeopathology"),
#'   region = c("proximal_third", "midshaft"),
#'   side_position = c("lateral", "medial")
#' )
#' plot_skeleton_base() + skeletograph_points(observations)
#'
#' # a different MetBrewer palette:
#' plot_skeleton_base() + skeletograph_points(observations, palette = "Renoir")
#' }
#' @export
skeletograph_points <- function(data, shapes = category_shapes(),
                                 colors = NULL, palette = "Hokusai1", size = 3) {
  required <- c("bone_name", "category", "region", "side_position")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    stop("`data` is missing required column(s): ", paste(missing_cols, collapse = ", "))
  }
  if (!"surface" %in% names(data)) data$surface <- NA
  if (!"subtype" %in% names(data)) data$subtype <- NA
  if (is.null(colors)) colors <- category_colors(palette = palette, categories = names(shapes))

  resolved_rows <- lapply(seq_len(nrow(data)), function(i) {
    loc <- resolve_location(
      bone_name     = data$bone_name[i],
      region        = data$region[i],
      side_position = data$side_position[i],
      surface       = data$surface[i]
    )
    loc$category <- data$category[i]
    loc$subtype  <- data$subtype[i]
    loc
  })
  resolved <- do.call(rbind, resolved_rows)

  unknown_shape_cat <- setdiff(unique(resolved$category), names(shapes))
  if (length(unknown_shape_cat) > 0) {
    stop(
      "category value(s) not found in `shapes`: ", paste(unknown_shape_cat, collapse = ", "),
      ". Pass a `shapes` vector that includes them, e.g. ",
      "shapes = c(category_shapes(), ", unknown_shape_cat[1], " = 8)"
    )
  }
  unknown_color_cat <- setdiff(unique(resolved$category), names(colors))
  if (length(unknown_color_cat) > 0) {
    stop(
      "category value(s) not found in `colors`: ", paste(unknown_color_cat, collapse = ", "),
      ". Pass a `colors` vector that includes them, e.g. ",
      "colors = c(category_colors(), ", unknown_color_cat[1], " = \"#FF00FF\")"
    )
  }

  list(
    ggplot2::geom_point(
      data = resolved,
      mapping = ggplot2::aes(x = x, y = y, shape = category, color = category),
      size = size,
      inherit.aes = FALSE
    ),
    ggplot2::scale_shape_manual(name = "Category", values = shapes),
    ggplot2::scale_color_manual(name = "Category", values = colors)
  )
}
