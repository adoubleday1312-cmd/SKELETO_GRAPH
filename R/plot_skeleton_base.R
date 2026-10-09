#' Draw the base skeleton
#'
#' Returns a bare `ggplot` object showing the full skeleton artwork -- the
#' bone outlines **plus** the grey shading and small detail paths that give
#' the illustration its depth -- drawn in the original SVG paint order. Add
#' [skeletograph_points()] or your own layers to it with `+`.
#'
#' Shading and detail paths always keep their original colours. Only the
#' bone (outline) paths can be recoloured, via `bone_fill` / `bone_color`;
#' leave both `NULL` to use the colours authored in the SVG (white bones,
#' black outlines).
#'
#' @param bone_fill optional fill colour applied to bone paths only.
#' @param bone_color optional outline colour applied to bone paths only.
#' @param linewidth outline width for all paths. Default `0.15`.
#' @return a `ggplot` object.
#' @examples
#' plot_skeleton_base()
#' @export
plot_skeleton_base <- function(bone_fill = NULL, bone_color = NULL, linewidth = 0.15) {
  polys <- .load_skeleton_polygons()
  is_bone <- !is.na(polys$bone_name)
  polys$plot_fill <- polys$fill
  polys$plot_stroke <- polys$stroke
  if (!is.null(bone_fill)) polys$plot_fill[is_bone] <- bone_fill
  if (!is.null(bone_color)) polys$plot_stroke[is_bone] <- bone_color

  ggplot2::ggplot() +
    ggplot2::geom_polygon(
      data = polys,
      mapping = ggplot2::aes(
        x = x, y = y, group = group_id,
        fill = I(plot_fill), colour = I(plot_stroke)
      ),
      linewidth = linewidth
    ) +
    ggplot2::coord_fixed() +
    ggplot2::theme_void() +
    ggplot2::theme(
      legend.key = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      plot.background = ggplot2::element_rect(fill = "transparent", colour = NA)
    )
}

