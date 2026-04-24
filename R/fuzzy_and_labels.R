#' Fuzzy left join with safety checks
#'
#' Wrapper around [fuzzyjoin::stringdist_left_join()] that:
#' - keeps only the best (minimum distance) match per left row,
#' - errors if any left key has no match,
#' - optionally errors if the best match is not one-to-one,
#' - warns when any match is inexact (distance > 0).
#'
#' The output includes an `exact_match` flag and renames left-hand key columns to
#' `*.input` to preserve both versions of the join keys.
#'
#' @param .left_df Left-hand data frame.
#' @param .right_df Right-hand data frame.
#' @param .max_distance Maximum string distance allowed.
#' @param .by Join specification passed to [fuzzyjoin::stringdist_left_join()].
#' @param .no_duplicates If `TRUE`, require one-to-one matching.
#' @param .name_of_merge Friendly name used in messages (e.g. "database").
#'
#' @return A tibble/data frame containing the joined columns and `exact_match`.
#' @export
stringdist_left_join_with_checks <- function(.left_df,
                                             .right_df,
                                             .max_distance = 1,
                                             .by,
                                             .no_duplicates = TRUE,
                                             .name_of_merge = "key") {
  right_df <- .right_df |> dplyr::mutate(right_id = dplyr::row_number())
  left_df <- .left_df |> dplyr::mutate(left_id = dplyr::row_number())
  merged_df <- fuzzyjoin::stringdist_left_join(
    left_df,
    right_df,
    by = .by,
    max_dist = .max_distance,
    distance_col = "dist"
  )
  if (length(.by) > 1) {
    dist_col_names <- names(merged_df)[stringr::str_detect(names(merged_df), ".dist")]
    merged_df$dist <- rowSums(merged_df[, dist_col_names])
  }
  merged_df <- merged_df |> dplyr::group_by(left_id) |> dplyr::filter(dist ==
                                                                        min(dist)) |> dplyr::ungroup()
  if (nrow(dplyr::filter(merged_df, is.na(right_id))) > 0)
    stop(paste0(
      "Error: can not find match for ",
      .name_of_merge,
      " please respecify"
    ))
  if (nrow(
    merged_df |> dplyr::group_by(left_id) |> dplyr::mutate(n = dplyr::n()) |> dplyr::filter(n >
                                                                                            1)
  ) > 0 &&
  .no_duplicates)
    stop("Error: duplicates in match please respecify")
  if (nrow(
    merged_df |> dplyr::group_by(right_id) |> dplyr::mutate(n = dplyr::n()) |> dplyr::filter(n >
                                                                                             1)
  ) > 0 &&
  .no_duplicates)
    stop("Error: duplicates in match please respecify")
  if (nrow(dplyr::filter(merged_df, dist > 0)))
    warning(paste0("Some inexact matches of ", .name_of_merge))
  merged_df <- merged_df |> dplyr::select(-right_id, -left_id) |> dplyr::mutate(exact_match = dist ==
                                                                                  0) |> dplyr::select(-dist)
  merged_df <- merged_df |> dplyr::rename_with( ~ stringr::str_replace(.x, stringr::fixed(".x"), ".input")) |> dplyr::rename_with( ~
                                                                                                                                     stringr::str_replace(.x, stringr::fixed(".y"), ""))
  merged_df
}

#' Convert a labels table to a spec table with ids (using fuzzy matching)
#'
#' Uses [list_databases()] and the schema endpoints to translate human-readable
#' `*_label` columns into Stat-Xplore `*_id` columns. Matching is done using
#' [stringdist_left_join_with_checks()] and will error when a label cannot be
#' matched within `.max_distance`.
#'
#' @param .input_tbl A tibble containing label columns that describe a query.
#'   Expected columns include `database_label`, `measure_label`, `field_label`,
#'   and either `value_label` or `value_code` (depending on the dataset).
#' @param .db_tbl Optional databases table from [list_databases()]; supplying
#'   avoids an extra API call.
#' @param .max_distance Maximum string distance allowed for matches.
#' @param .db_child_info Optional pre-fetched result of
#'   [get_target_type_info_below()] for `c("MEASURE", "COUNT", "FIELD")` with
#'   columns prefixed `child_`; avoids a repeated schema fetch when calling
#'   this function in a loop.
#' @param .pot_valueset_info Optional pre-fetched valueset info tibble (as
#'   built internally from field locations); avoids repeated schema fetches
#'   when calling this function in a loop.
#'
#' @return A spec table (tibble) with `database_id`, `measure_id`, `field_id`,
#'   `value_id`, and match diagnostics (e.g. `*_exact_match`).
#' @export
convert_labels_table_to_spec_table <- function(.input_tbl,
                                               .db_tbl = NULL,
                                               .max_distance = 1,
                                               .db_child_info = NULL,
                                               .pot_valueset_info = NULL) {
  dbs <- if (!is.null(.db_tbl))
    .db_tbl
  else
    list_databases()
  .input_tbl <- .input_tbl |> dplyr::select(dplyr::ends_with("_label"), dplyr::ends_with("_code"))
  db_label <- .input_tbl |> dplyr::distinct(database_label) |> dplyr::pull()
  if (length(db_label) > 1)
    stop("Must only be one value for database in table")
  db_label_tbl <- tibble::tibble("label" = db_label)
  db_info <- stringdist_left_join_with_checks(
    db_label_tbl,
    dbs,
    .by = c("label"),
    .max_distance = .max_distance,
    .name_of_merge = "database"
  ) |>
    dplyr::select(label, label.input, id, location, exact_match) |> dplyr::rename_with( ~
                                                                                          paste0("database_", .x))
  db_loc <- db_info |> dplyr::pull(database_location)
  db_child_info <- if (!is.null(.db_child_info)) {
    .db_child_info
  } else {
    get_target_type_info_below(.url = db_loc,
                               .target_types = c("MEASURE", "COUNT", "FIELD")) |>
      dplyr::rename_with(~ paste0("child_", .x))
  }
  measure_label_tbl <- .input_tbl |> dplyr::distinct(measure_label)
  measure_label <- measure_label_tbl |> dplyr::pull(measure_label)
  if (length(measure_label) > 1)
    stop("Must only be one value for measure in table")
  measure_info <- stringdist_left_join_with_checks(
    measure_label_tbl,
    db_child_info,
    .by = c("measure_label" = "child_label"),
    .max_distance = .max_distance,
    .name_of_merge = "measure"
  ) |>
    dplyr::select(
      dplyr::starts_with("child_"),
      measure_exact_match = exact_match,
      measure_label.input = measure_label
    ) |>
    dplyr::rename_with(
      ~ stringr::str_replace(.x, "child_", "measure_"),
      -measure_label.input,
      -measure_exact_match
    )
  fields <- .input_tbl |> dplyr::distinct(field_label)
  fields_info <- stringdist_left_join_with_checks(
    fields,
    db_child_info,
    .by = c("field_label" = "child_label"),
    .max_distance = .max_distance,
    .name_of_merge = "field"
  ) |>
    dplyr::select(dplyr::starts_with("child_"),
                  exact_match,
                  field_label.input = field_label) |>
    dplyr::rename_with( ~ stringr::str_replace(.x, "child_", "field_")) |> dplyr::rename(field_exact_match =
                                                                                           exact_match)
  pot_valueset_info <- if (!is.null(.pot_valueset_info)) {
    .pot_valueset_info
  } else {
    purrr::map(
      fields_info$field_location,
      ~ get_target_type_info_below(.url = .x, .target_types = "VALUESET") |>
        dplyr::mutate(field_location = .x)
    ) |> dplyr::bind_rows() |>
      dplyr::select(-type) |>
      dplyr::rename_with(~ paste0("valueset_", .x), -field_location) |>
      dplyr::left_join(fields_info, by = c("field_location")) |>
      dplyr::select(-dplyr::ends_with(".input"))
  }
  input_tbl_adj <- .input_tbl
  if (!"value_code" %in% names(.input_tbl))
    input_tbl_adj["value_code"] <- NA
  value_labels_tbl <- input_tbl_adj |> dplyr::distinct(field_label, value_label, valueset_label, value_code)
  missingrows <- value_labels_tbl |> dplyr::filter(is.na(valueset_label) |
                                                     (is.na(value_label) & is.na(value_code)))
  if (nrow(missingrows) > 0)
    stop("Each row needs a valueset label and either a value_label or value_code")
  value_code_rows <- value_labels_tbl |> dplyr::filter(!is.na(value_code))
  if (nrow(value_code_rows) > 0) {
    valuesets_tbl <- value_code_rows |> dplyr::distinct(valueset_label) |>
      stringdist_left_join_with_checks(
        pot_valueset_info,
        .by = c("valueset_label" = "valueset_label"),
        .max_distance = .max_distance,
        .name_of_merge = "valueset"
      )
    value_code_rows <- dplyr::left_join(value_code_rows, valuesets_tbl, by =
                                          "valueset_label") |>
      dplyr::mutate(
        value_id_prefix = stringr::str_replace(valueset_id, "str:valueset:", "str:value:"),
        value_id = paste0(value_id_prefix, ":", value_code)
      )
  }
  value_label_rows_input <- value_labels_tbl |>
    dplyr::filter(!is.na(value_label) & is.na(value_code))
  if (nrow(value_label_rows_input) > 0) {
    # Only fetch value-level schema when there are label-based rows to match
    pot_values_info <- purrr::map(
      pot_valueset_info$valueset_location,
      ~ get_schema_info(url = .x)
    ) |> dplyr::bind_rows() |>
      dplyr::select(-type) |>
      dplyr::rename_with(~ stringr::str_replace(.x, "child_", "value_")) |>
      dplyr::select(dplyr::starts_with("value_"), valueset_location = location) |>
      dplyr::left_join(pot_valueset_info, by = c("valueset_location")) |>
      dplyr::select(-dplyr::ends_with(".input")) |>
      tidyr::drop_na(value_id)
    value_label_rows <- stringdist_left_join_with_checks(
      value_label_rows_input,
      pot_values_info,
      .by = c("value_label", "field_label", "valueset_label"),
      .max_distance = .max_distance,
      .name_of_merge = "value"
    )
  }
  out_tbl <- .input_tbl |> dplyr::rename_with( ~ paste0(.x, ".input")) |> dplyr::rename_with( ~
                                                                                                stringr::str_replace(.x, "value_group.input", "value_group"))
  if (!"value_group" %in% names(.input_tbl))
    out_tbl["value_group"] <- NA
  out_tbl <- out_tbl |>
    dplyr::left_join(db_info, by = "database_label.input", relationship =
                       "many-to-one") |>
    dplyr::left_join(measure_info, by = "measure_label.input", relationship =
                       "many-to-one") |>
    dplyr::left_join(fields_info, by = "field_label.input", relationship =
                       "many-to-one") |>
    dplyr::mutate(.row_id = dplyr::row_number())
  # Join code-based and label-based rows separately to avoid NA collisions:
  # if processed value_tbl has a code but the raw input does not (or vice
  # versa), a combined join on value_code would silently drop matches.
  code_part <- out_tbl |> dplyr::filter(!is.na(value_code.input))
  if (nrow(code_part) > 0) {
    code_value_tbl <- value_code_rows |>
      dplyr::select(-dplyr::starts_with("field_")) |>
      dplyr::rename(value_exact_match = exact_match)
    code_part <- code_part |>
      dplyr::left_join(
        code_value_tbl,
        by = c("valueset_label.input", "value_code.input" = "value_code"),
        relationship = "one-to-one"
      )
  }
  label_part <- out_tbl |> dplyr::filter(is.na(value_code.input))
  if (nrow(label_part) > 0 && nrow(value_label_rows_input) > 0) {
    label_value_tbl <- value_label_rows |>
      dplyr::select(-dplyr::starts_with("field_")) |>
      dplyr::rename(value_exact_match = exact_match)
    label_part <- label_part |>
      dplyr::left_join(
        label_value_tbl,
        by = c("valueset_label.input", "value_label.input"),
        relationship = "one-to-one"
      )
  }
  dplyr::bind_rows(code_part, label_part) |>
    dplyr::arrange(.row_id) |>
    dplyr::select(-.row_id)
}
