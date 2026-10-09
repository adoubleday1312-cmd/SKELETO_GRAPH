# ------------------------------------------------------------------
# data-raw/category_subtypes.R
# Builds the subtype vocabulary for skeletograph:
#   category > group > condition > subcondition
# Categories covered: palaeopathology, trauma, taphonomy.
# (entheseal_change has no subtypes, so it has no rows here.)
#
# Aliases (abbreviations / alternative names) let free text such as
# "NSPL", "periostitis" or "Potts disease" resolve to the right subtype.
#
# Base R only. Run from the package root.
# ------------------------------------------------------------------

row <- function(category, group = NA_character_, condition,
                subcondition = NA_character_, aliases = NA_character_) {
  data.frame(
    category     = category,
    group        = group,
    condition    = condition,
    subcondition = subcondition,
    aliases      = aliases,
    stringsAsFactors = FALSE
  )
}

pal  <- "palaeopathology"
inf  <- "Infectious markers"
gen  <- "General/non-specific"
met  <- "Metabolic indicators"
arth <- "Arthropathies"
cong <- "Congenital conditions"

category_subtypes <- do.call(rbind, list(

  # ---- PALAEOPATHOLOGY ---------------------------------------------

  # a. Infectious markers
  row(pal, inf, "Tuberculosis",
      aliases = "Pott's disease|Mycobacterium tuberculosis"),
  row(pal, inf, "Brucellosis"),
  row(pal, inf, "Septic arthritis"),
  row(pal, inf, "Leprosy"),
  row(pal, inf, "Treponemal conditions"),
  row(pal, inf, "Treponemal conditions", "Syphilis"),
  row(pal, inf, "Treponemal conditions", "Yaws"),
  row(pal, inf, "Treponemal conditions", "Bejel"),

  # b. General / non-specific
  row(pal, gen, "New periosteal bone formation", aliases = "NSPL|Periostitis"),
  row(pal, gen, "Erosive lesions"),
  row(pal, gen, "Proliferative lesions"),

  # c. Metabolic indicators
  row(pal, met, "Cribra orbitalia"),
  row(pal, met, "Porotic hyperostosis"),
  row(pal, met, "Linear enamel hypoplasia", aliases = "LEH"),
  row(pal, met, "Scurvy"),
  row(pal, met, "Rickets"),
  row(pal, met, "Osteomalacia"),

  # d. Arthropathies (osteoarthritis and DJD deliberately kept separate)
  row(pal, arth, "Osteoarthritis"),
  row(pal, arth, "Degenerative joint disease"),
  row(pal, arth, "Schmorl's nodes", aliases = "Schmorl nodes"),
  row(pal, arth, "Psoriatic arthritis"),
  row(pal, arth, "Rheumatoid arthritis"),

  # e. Congenital conditions
  row(pal, cong, "Dwarfism"),
  row(pal, cong, "Dwarfism", "Achondroplasia"),
  row(pal, cong, "Chromosomal developmental disorders"),
  row(pal, cong, "Chromosomal developmental disorders", "Trisomy 21",
      aliases = "Down's syndrome|Down syndrome"),
  row(pal, cong, "Chromosomal developmental disorders", "Klippel-Feil syndrome",
      aliases = "Klippel Feil syndrome"),
  row(pal, cong, "Scoliosis"),
  row(pal, cong, "Congenitally acquired treponemal conditions"),

  # ---- TRAUMA ------------------------------------------------------
  row("trauma", condition = "Sharp-force trauma"),
  row("trauma", condition = "Blunt-force trauma"),

  # ---- TAPHONOMY ---------------------------------------------------
  row("taphonomy", condition = "Erosion"),
  row("taphonomy", condition = "Abrasion"),
  row("taphonomy", condition = "Rodent gnawing"),
  row("taphonomy", condition = "Post-mortem modification")
))

# ---- stable IDs ---------------------------------------------------
slug <- function(x) {
  x <- tolower(gsub("[\u2019']", "", x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_+|_+$", "", x)
}

category_subtypes$subtype_id <- mapply(
  function(cat, g, cond, sub) {
    parts <- c(cat, if (!is.na(g)) g, cond, if (!is.na(sub)) sub)
    paste(slug(parts), collapse = ".")
  },
  category_subtypes$category,
  category_subtypes$group,
  category_subtypes$condition,
  category_subtypes$subcondition,
  USE.NAMES = FALSE
)

stopifnot(!anyDuplicated(category_subtypes$subtype_id))

# ---- alias resolver (goes in R/, shown here for reference) --------
normalise_term <- function(x) {
  x <- tolower(gsub("[\u2019'`]", "", x))      # Pott's -> potts
  trimws(gsub("[^a-z0-9]+", " ", x))           # Klippel-Feil -> klippel feil
}

#' Resolve free-text terms to subtype IDs
#' Matches condition/subcondition names and aliases, ignoring case,
#' punctuation and apostrophes. Supply `category` to restrict matching
#' (e.g. category = "taphonomy"). Unmatched terms return NA with a warning.
resolve_subtype <- function(terms, category = NULL, table = category_subtypes) {
  if (!is.null(category)) table <- table[table$category %in% category, ]

  labels <- ifelse(is.na(table$subcondition), table$condition,
                   table$subcondition)
  keys <- lapply(seq_len(nrow(table)), function(i) {
    a <- if (is.na(table$aliases[i])) character(0) else
      strsplit(table$aliases[i], "|", fixed = TRUE)[[1]]
    normalise_term(c(labels[i], a))
  })

  out <- vapply(terms, function(tm) {
    hit <- which(vapply(keys, function(k) normalise_term(tm) %in% k, logical(1)))
    if (length(hit) == 1) table$subtype_id[hit] else NA_character_
  }, character(1), USE.NAMES = FALSE)

  if (anyNA(out)) {
    warning("Unrecognised subtype(s): ",
            paste(terms[is.na(out)], collapse = ", "), call. = FALSE)
  }
  out
}

# Quick check:
# resolve_subtype(c("NSPL", "Potts disease", "LEH", "Down syndrome"))
# resolve_subtype("rodent gnawing", category = "taphonomy")

# ---- save ---------------------------------------------------------
write.csv(category_subtypes, "data-raw/category_subtypes.csv",
          row.names = FALSE)

if (requireNamespace("usethis", quietly = TRUE)) {
  usethis::use_data(category_subtypes, overwrite = TRUE)
}
