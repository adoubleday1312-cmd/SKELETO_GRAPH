test_that("list_bones returns a non-empty sorted character vector", {
  bones <- list_bones()
  expect_type(bones, "character")
  expect_true(length(bones) > 0)
  expect_identical(bones, sort(bones))
  expect_true("femur_R" %in% bones)
  expect_true("cranium" %in% bones)
  expect_true("hand_L" %in% bones)
})

test_that("resolve_location returns one row with numeric x/y for a long bone", {
  loc <- resolve_location("femur_R", region = "midshaft", side_position = "lateral")
  expect_equal(nrow(loc), 1)
  expect_type(loc$x, "double")
  expect_type(loc$y, "double")
  expect_equal(loc$bone_name, "femur_R")
})

test_that("proximal and distal resolve to different y on a long bone", {
  prox <- resolve_location("femur_R", region = "proximal", side_position = "central")
  dist <- resolve_location("femur_R", region = "distal", side_position = "central")
  expect_true(prox$y > dist$y) # proximal (superior) should be higher after y-flip
})

test_that("medial/lateral flip direction between R and L sided bones", {
  medial_r <- resolve_location("femur_R", region = "midshaft", side_position = "medial")
  lateral_r <- resolve_location("femur_R", region = "midshaft", side_position = "lateral")
  medial_l <- resolve_location("femur_L", region = "midshaft", side_position = "medial")
  lateral_l <- resolve_location("femur_L", region = "midshaft", side_position = "lateral")

  # R-side medial should sit closer to the body midline (higher x) than R-side lateral
  expect_true(medial_r$x > lateral_r$x)
  # L-side medial should sit closer to the midline (lower x) than L-side lateral
  expect_true(medial_l$x < lateral_l$x)
})

test_that("invalid region or side_position errors informatively", {
  expect_error(resolve_location("femur_R", region = "not_a_term"), "not valid")
  expect_error(resolve_location("cranium", region = "midshaft"), "not valid")
  expect_error(resolve_location("not_a_bone"), "Unknown bone_name")
})

test_that("grouped regions only support 'central'", {
  vocab <- skeletograph_vocabulary("hand_L")
  expect_equal(vocab$region, "central")
  expect_equal(vocab$side_position, "central")
  expect_error(resolve_location("hand_L", region = "midshaft"), "not valid")
})

test_that("skeletograph_points errors clearly on missing columns", {
  bad_data <- data.frame(bone_name = "femur_R", category = "trauma")
  expect_error(skeletograph_points(bad_data), "missing required column")
})

test_that("skeletograph_points errors on unrecognised category", {
  obs <- data.frame(
    bone_name = "femur_R", category = "not_a_category",
    region = "midshaft", side_position = "central"
  )
  expect_error(skeletograph_points(obs), "not found in `shapes`")
})

test_that("skeletograph_heatmap errors clearly on missing columns", {
  bad_data <- data.frame(bone_name = "femur_R", category = "trauma")
  expect_error(skeletograph_heatmap(bad_data), "missing required column")
})

test_that("category_shapes uses 'taphonomy' with a diamond shape", {
  shapes <- category_shapes()
  expect_true("taphonomy" %in% names(shapes))
  expect_false("taphonomic_modification" %in% names(shapes))
  expect_equal(unname(shapes["taphonomy"]), 18)
})

test_that("category_shapes includes 'artefacts' with a star shape", {
  shapes <- category_shapes()
  expect_true("artefacts" %in% names(shapes))
  expect_equal(unname(shapes["artefacts"]), 8)
})

test_that("category_colors returns one colour per category, works without MetBrewer too", {
  cols <- category_colors()
  expect_equal(names(cols), names(category_shapes()))
  expect_true(all(grepl("^#", cols)))
})

test_that("skeletograph_heatmap errors on unrecognised bone_name", {
  bad_data <- data.frame(bone_name = "not_a_bone", category = "trauma", value = 1)
  expect_error(skeletograph_heatmap(bad_data), "not recognised")
})
