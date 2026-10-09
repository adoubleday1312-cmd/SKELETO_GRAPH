#' Plot population-level average observations as a per-bone heatmap
#'
#' Separate from [skeletograph_points()]: instead of individual observations
#' at specific locations, this aggregates observations *per skeletal
#' element* across a population (or sample) and colours each whole bone by
#' the aggregated value, using a continuous gradient (a density / heatmap
#' scale) -- drawn over the full skeleton artwork (shading and detail
#' included) so it doesn't look flat.
#'
#' @section Rendering note:
#' Bone fill needs to map to your data's `value` through a continuous
#' gradient scale, but the shading/detail paths must keep their own
#' original colours regardless of the data -- ggplot2 only supports one
#' scale per aesthetic per plot, so these can't both be driven by the same
#' `fill` scale in a single layer. This function draws them as two stacked
#' `geom_polygon()` layers instead: all shading/detail paths first (their
#' own colours, via `I()`, bypassing the scale), then the bone paths on top
#' (mapped through `scale_fill_gradient()`). This reproduces the *local*
#' paint order that matters (a bone's own shading sits behind it) but does
#' collapse cross-bone ordering -- a rare case where one bone's shading was
#' meant to fall on top of a neighbouring bone's outline will not be
#' reproduced exactly. Visually negligible for this artwork.
#'
#' @param data a data.frame with required columns:
#'   \describe{
#'     \item{bone_name}{e.g. `"femur_R"`. See [list_bones()]. The whole bone
#'       is coloured as one unit -- no `region`/`side_position` needed.}
#'     \item{category}{recording category, e.g. `"trauma"`. Categories are
#'       aggregated separately (see `category_filter`), never combined into
#'       one number.}
#'     \item{value}{numeric observation to aggregate per bone_name +
#'       category -- a 0/1 presence flag (giving a prevalence rate once
#'       averaged), a severity score, or a raw count.}
#'   }
#' @param category_filter optional single category name. If omitted and
#'   more than one category is present, the plot is faceted by category.
#' @param aggregate_fun function combining multiple rows sharing a
#'   bone_name + category. Default `mean`.
#' @param palette name of a MetBrewer palette (see [category_colors()] for
#'   credit) used to derive `low_color`/`high_color` when they're not given
#'   explicitly. Default `"Hokusai1"`.
#' @param low_color,high_color the two ends of the gradient scale. Default
#'   `NULL`, meaning "take the first and last colour of `palette`".
#' @param na_color fill for bones with no matching observations.
#' @return a `ggplot` object (includes the full skeleton artwork already --
#'   don't add this to [plot_skeleton_base()], it draws its own).
#' @examples
#' \dontrun{
#' pop_data <- data.frame(
#'   bone_name = rep(c("femur_R", "femur_L", "tibia_R"), times = c(5, 3, 4)),
#'   category  = "trauma",
#'   value     = c(1, 0, 1, 1, 0,  0, 1, 0,  1, 1, 0, 1)
#' )
#' skeletograph_heatmap(pop_data)
#'
#' # a different MetBrewer palette:
#' skeletograph_heatmap(pop_data, palette = "Renoir")
#' }
#' @export
skeletograph_heatmap <- function(data, category_filter = NULL, aggregate_fun = mean,
                                  palette = "Hokusai1", low_color = NULL, high_color = NULL,
                                  na_color = "grey90") {
  if (is.null(low_color) || is.null(high_color)) {
    pal_ends <- category_colors(palette = palette, categories = c("low", "high"))
    if (is.null(low_color)) low_color <- unname(pal_ends["low"])
    if (is.null(high_color)) high_color <- unname(pal_ends["high"])
  }
  required <- c("bone_name", "category", "value")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    stop("`data` is missing required column(s): ", paste(missing_cols, collapse = ", "))
  }
  if (!is.null(category_filter)) {
    data <- data[data$category == category_filter, , drop = FALSE]
    if (nrow(data) == 0) stop("No rows in `data` match category_filter = '", category_filter, "'")
  }
  unknown_bones <- setdiff(unique(data$bone_name), list_bones())
  if (length(unknown_bones) > 0) {
    stop("bone_name value(s) not recognised: ", paste(unknown_bones, collapse = ", "),
         ". See list_bones() for valid names.")
  }

  agg <- stats::aggregate(value ~ bone_name + category, data = data, FUN = aggregate_fun)
  categories <- unique(agg$category)
  facet_needed <- is.null(category_filter) && length(categories) > 1

  polys <- .load_skeleton_polygons()
  background <- polys[is.na(polys$bone_name), ]
  bones <- polys[!is.na(polys$bone_name), ]

  build_bone_layer <- function(cat) {
    d <- merge(bones, agg[agg$category == cat, c("bone_name", "value")],
               by = "bone_name", all.x = TRUE)
    d$category <- cat
    d[order(d$order_index, d$subpath_id, d$vertex_order), ]
  }
  bone_data <- if (facet_needed) {
    do.call(rbind, lapply(categories, build_bone_layer))
  } else {
    build_bone_layer(if (is.null(category_filter)) categories[1] else category_filter)
  }

  p <- ggplot2::ggplot() +
    ggplot2::geom_polygon(
      data = background,
      mapping = ggplot2::aes(x = x, y = y, group = group_id, fill = I(fill), colour = I(stroke)),
      linewidth = 0.15
    ) +
    ggplot2::geom_polygon(
      data = bone_data,
      mapping = ggplot2::aes(x = x, y = y, group = group_id, fill = value),
      colour = "black", linewidth = 0.15
    ) +
    ggplot2::scale_fill_gradient(low = low_color, high = high_color, na.value = na_color,
                                  name = "Average\nobservations") +
    ggplot2::coord_fixed() +
    ggplot2::theme_void() +
    ggplot2::theme(
      legend.key = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      plot.background = ggplot2::element_rect(fill = "transparent", colour = NA)
    )

  if (facet_needed) p <- p + ggplot2::facet_wrap(~category)
  p
}
