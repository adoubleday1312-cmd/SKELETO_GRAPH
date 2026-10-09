#' Read observation data for skeletograph from a spreadsheet
#'
#' Reads a .xlsx/.xls (via the readxl package) or .csv file into a
#' data.frame shaped for [skeletograph_points()] ("points" format) or
#' [skeletograph_heatmap()] ("population" format) -- so a full
#' osteobiography or a population sample can be prepared in Excel rather
#' than typed into R by hand.
#'
#' This only reads and tidies the file (normalises column names, trims
#' whitespace, coerces `value` to numeric for population format) -- it does
#' NOT validate bone_name/category values itself. Pass the result straight
#' to [skeletograph_points()] or [skeletograph_heatmap()], which already
#' validate those and will name the offending value in the error if
#' something in the spreadsheet doesn't match the package's vocabulary.
#'
#' @param path path to a .xlsx, .xls, or .csv file.
#' @param format `"points"` (default) requires bone_name, category, region,
#'   side_position columns (optional: subtype, surface) -- one row per
#'   individual observation, e.g. a full osteobiography. `"population"`
#'   requires bone_name, category, value -- one row per bone+category
#'   observation across many individuals.
#' @param sheet sheet name or number, for multi-sheet .xlsx files. Passed to
#'   `readxl::read_excel()`. Ignored for .csv.
#' @return a data.frame with normalised column names (lowercase, spaces/dots
#'   -> underscores), ready for [skeletograph_points()] or
#'   [skeletograph_heatmap()].
#' @examples
#' \dontrun{
#' obs <- read_skeletograph_data("individual_014_osteobiography.xlsx")
#' plot_skeleton_base() + skeletograph_points(obs)
#'
#' pop <- read_skeletograph_data("population_trauma.xlsx", format = "population")
#' skeletograph_heatmap(pop)
#' }
#' @export
read_skeletograph_data <- function(path, format = c("points", "population"), sheet = 1) {
  format <- match.arg(format)
  if (!file.exists(path)) stop("File not found: ", path)

  ext <- tolower(tools::file_ext(path))
  data <- if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop(
        "Reading .xlsx/.xls files needs the readxl package. Install it with:\n",
        '  install.packages("readxl")'
      )
    }
    as.data.frame(readxl::read_excel(path, sheet = sheet))
  } else if (ext == "csv") {
    utils::read.csv(path, stringsAsFactors = FALSE)
  } else {
    stop("Unsupported file type '.", ext, "' -- use .xlsx, .xls, or .csv")
  }

  names(data) <- tolower(trimws(names(data)))
  names(data) <- gsub("[ .]+", "_", names(data))

  required <- if (format == "points") {
    c("bone_name", "category", "region", "side_position")
  } else {
    c("bone_name", "category", "value")
  }
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    stop(
      "'", path, "' is missing required column(s) for format = \"", format, "\": ",
      paste(missing_cols, collapse = ", "), ".\n",
      "Columns found: ", paste(names(data), collapse = ", ")
    )
  }

  char_cols <- vapply(data, is.character, logical(1))
  data[char_cols] <- lapply(data[char_cols], trimws)

  if (format == "population") {
    data$value <- as.numeric(data$value)
  }

  data
}

#' Reshape a wide one-row-per-individual spreadsheet into long population format
#'
#' Many recording spreadsheets have one row per individual and one column
#' per skeletal element (e.g. a "trauma" recording form with columns
#' `femur_R`, `femur_L`, `tibia_R`... holding a 0/1 or severity score per
#' individual). [skeletograph_heatmap()] needs one row per bone_name +
#' category observation instead -- this converts the former into the
#' latter, so you can point it at a recording form you're already using
#' rather than re-entering data.
#'
#' @param data a data.frame -- e.g. read directly with
#'   `readxl::read_excel()` when your sheet is wide.
#' @param category the category label assigned to every reshaped
#'   observation (a wide recording sheet is normally all one category --
#'   one "trauma" form, one "entheseal_change" form, etc.).
#' @param id_cols column name(s) identifying an individual (e.g.
#'   `"individual_id"`), kept as-is rather than melted. If `NULL` (default),
#'   every column not in `bone_cols` is treated as an id column.
#' @param bone_cols column names to treat as skeletal elements, matching
#'   [list_bones()]. If `NULL` (default), every column not in `id_cols` is
#'   treated as a bone column. Supply at least one of `id_cols`/`bone_cols`.
#' @return a long-format data.frame (bone_name, category, value, plus any
#'   id_cols), ready for [skeletograph_heatmap()].
#' @examples
#' \dontrun{
#' wide <- readxl::read_excel("population_trauma_wide.xlsx")
#' # wide has columns: individual_id, femur_R, femur_L, tibia_R, tibia_L, ...
#' pop <- reshape_population_wide(wide, category = "trauma", id_cols = "individual_id")
#' skeletograph_heatmap(pop)
#' }
#' @export
reshape_population_wide <- function(data, category, id_cols = NULL, bone_cols = NULL) {
  # NB: headers are only trimmed/underscored here, NOT lower-cased -- unlike
  # read_skeletograph_data(), a wide sheet's column headers ARE the bone_name
  # values once melted (e.g. "femur_R"), and bone names are case-sensitive.
  names(data) <- trimws(names(data))
  names(data) <- gsub("[ .]+", "_", names(data))

  if (is.null(id_cols) && is.null(bone_cols)) {
    stop("Supply at least one of `id_cols` or `bone_cols` so I know which columns are skeletal elements.")
  }
  if (is.null(bone_cols)) bone_cols <- setdiff(names(data), id_cols)
  if (is.null(id_cols)) id_cols <- setdiff(names(data), bone_cols)

  missing_bone_cols <- setdiff(bone_cols, names(data))
  if (length(missing_bone_cols) > 0) {
    stop("bone_cols not found in data: ", paste(missing_bone_cols, collapse = ", "))
  }

  unknown_bones <- setdiff(bone_cols, list_bones())
  if (length(unknown_bones) > 0) {
    warning(
      "These bone_cols don't match any known bone_name (see list_bones()) and will error ",
      "if passed to skeletograph_heatmap() as-is: ", paste(unknown_bones, collapse = ", ")
    )
  }

  rows <- lapply(bone_cols, function(bc) {
    out <- data[, id_cols, drop = FALSE]
    out$bone_name <- bc
    out$category <- category
    out$value <- suppressWarnings(as.numeric(data[[bc]]))
    out
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

