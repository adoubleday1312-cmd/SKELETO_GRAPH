# These are ggplot2 aes()/NSE column-name references, not real global
# variables -- this just tells R CMD check that's expected, so
# devtools::check() doesn't flag them as a NOTE.
utils::globalVariables(c(
  "x", "y", "group_id", "category", "value",
  "fill", "stroke", "plot_fill", "plot_stroke"
))
