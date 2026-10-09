#' Default colours for the four recording categories
#'
#' Colours default to the **Hokusai1** palette from the
#' \href{https://github.com/BlakeRMills/MetBrewer}{MetBrewer} package by
#' Blake Robert Mills -- palettes inspired by works held at the
#' Metropolitan Museum of Art, this one after Katsushika Hokusai. MetBrewer
#' is a Suggests dependency: install it with `install.packages("MetBrewer")`
#' to use palette-based colouring; without it, [skeletograph_points()] and
#' [skeletograph_heatmap()] still work, falling back to a small built-in
#' set of colours.
#'
#' @param palette name of a MetBrewer palette, passed to
#'   `MetBrewer::met.brewer()`. Default `"Hokusai1"`. Run
#'   `MetBrewer::met.brewer("all")` to browse the full set (Hiroshige,
#'   Renoir, Isfahan1, Klimt, VanGogh1... over 50 palettes drawn from
#'   different artists and periods).
#' @param categories character vector of category names to assign colours
#'   to, in order. Defaults to the four built-in categories.
#' @return a named character vector of hex colours, one per category.
#' @examples
#' \dontrun{
#' category_colors()
#' category_colors(palette = "Renoir")
#' }
#' @export
category_colors <- function(palette = "Hokusai1",
                             categories = c("palaeopathology", "trauma",
                                            "entheseal_change", "taphonomy")) {
  n <- length(categories)
  cols <- tryCatch(
    unname(MetBrewer::met.brewer(palette, n)),
    error = function(e) NULL
  )
  if (is.null(cols)) {
    # MetBrewer not installed, or fewer/more colours than the palette
    # supports -- fall back to a small fixed set rather than erroring, since
    # colour is a visual nicety and shouldn't block plotting.
    fallback <- c("#B75347", "#224B5E", "#E09351", "#94B594", "#EDC775", "#6D2F20", "#DF7E66")
    cols <- rep(fallback, length.out = n)
  }
  stats::setNames(as.character(cols), categories)
}
