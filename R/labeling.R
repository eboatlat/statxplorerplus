# Label and location helpers ---------------------------------------------------

#' Traverse down from a schema URL and collect records of chosen types
#'
#' Walks the Stat-Xplore schema tree breadth-first from `.url`, repeatedly
#' fetching children using [get_next_level_info()]. At each step, rows whose
#' `type` matches `.target_types` are collected into a single tibble.
#'
#' @param .url A schema `location` URL to start from (e.g. a database location).
#' @param .target_types Character vector of schema types to collect, e.g.
#'   `c("MEASURE", "FIELD")`.
#' @param .max_iterations Maximum number of traversal steps.
#' @param .error_if_empty If `TRUE` (default), error when no records of
#'   `.target_types` are found after full traversal. Set to `FALSE` to return
#'   an empty tibble instead.
#'
#' @return A tibble of matching schema records.
#' @export
get_target_type_info_below <- function(.url, .target_types, .max_iterations = 10,
                                       .error_if_empty = TRUE) {
  target_info <- tibble::tibble()
  paths <- .url

  for (i in 1:.max_iterations) {
    nextlevel <- purrr::map(paths, ~ get_next_level_info(.x, error_if_next_level_empty = FALSE)) |>
      dplyr::bind_rows()

    target_info <- dplyr::bind_rows(
      target_info,
      nextlevel |> dplyr::filter(type %in% .target_types)
    )

    # VALUE nodes are leaves and never contain other target types
    paths <- nextlevel |>
      dplyr::filter(!type %in% .target_types, type != "VALUE") |>
      dplyr::pull(location)

    if (is.vector(paths) && length(paths) == 0) break
  }

  if (.error_if_empty && nrow(target_info) == 0) {
    stop(paste0(
      "No schema records of type ",
      paste(sQuote(.target_types), collapse = " or "),
      " found below the supplied URL. Check that the type string(s) are correct."
    ))
  }

  target_info
}

#' Enrich a spec table with labels and schema locations
#'
#' Takes a tidy spec table with `*_id` columns and joins on human-readable
#' labels and schema `location` URLs for the database, measure, fields, and
#' values.
#'
#' This is primarily intended to support workflows that start from ids (e.g.
#' [convert_json_to_spec_table()]) and need labels for matching, auditing, or
#' exporting.
#'
#' @param .input_tbl A spec table with `database_id`, `measure_id`, `field_id`,
#'   and `value_id`.
#' @param .db_tbl Optional tibble of databases as returned by [list_databases()].
#'   Supplying this avoids re-fetching the database list.
#'
#' @return A tibble containing the input columns plus `*_label`, `*_location`,
#'   and helper fields such as `value_code`. Columns are prefixed with
#'   `database_`, `measure_`, `field_`, `valueset_`, and `value_`.
#' @export
add_labels_and_locations_to_spec_table <- function(.input_tbl, .db_tbl = NULL) {
  db_id <- .input_tbl |> dplyr::distinct(database_id) |> dplyr::pull()
  if (length(db_id) > 1) stop("Must only be one value for database in table")

  dbs <- if (!is.null(.db_tbl)) .db_tbl else list_databases()
  db_location <- dbs |> dplyr::filter(id == db_id) |> dplyr::pull(location)

  db_info <- get_schema_info(db_location)
  db_child_info <- get_target_type_info_below(db_location, .target_types = c("MEASURE", "COUNT", "FIELD"))

  measure_id <- .input_tbl |> dplyr::distinct(measure_id) |> dplyr::pull()
  if (length(measure_id) > 1) stop("Must only be one measure for database in table")

  measure_info <- db_child_info |>
    dplyr::filter(id == measure_id) |>
    dplyr::rename_with(~ paste0("measure_", .x)) |>
    dplyr::select(-measure_type) |>
    convert_list_column_to_string(list_col_name = "measure_functions")

  field_ids <- .input_tbl |> dplyr::distinct(field_id) |> dplyr::pull()

  fields_info <- db_child_info |>
    dplyr::filter(id %in% field_ids) |>
    dplyr::rename_with(~ paste0("field_", .x)) |>
    dplyr::select(-field_type) |>
    convert_list_column_to_string(list_col_name = "field_functions")

  values_info <- purrr::map(fields_info$field_location, ~ get_target_type_info_below(.url = .x, .target_types = "VALUE")) |>
    dplyr::bind_rows() |>
    dplyr::select(-type) |>
    dplyr::rename_with(~ paste0("value_", .x))

  valueset_info <- purrr::map(fields_info$field_location, ~ get_target_type_info_below(.url = .x, .target_types = "VALUESET")) |>
    dplyr::bind_rows() |>
    dplyr::select(-type) |>
    dplyr::rename_with(~ paste0("valueset_", .x))

  out_tbl <- .input_tbl

  db_info_for_join <- db_info |>
    dplyr::select(id, location, label) |>
    dplyr::distinct() |>
    dplyr::rename_with(~ paste0("database_", .x), dplyr::everything())

  out_tbl <- dplyr::left_join(out_tbl, db_info_for_join, by = c("database_id"), relationship = "many-to-one")
  out_tbl <- dplyr::left_join(out_tbl, measure_info, by = c("measure_id"), relationship = "many-to-one")
  out_tbl <- dplyr::left_join(out_tbl, fields_info, by = c("field_id"), relationship = "many-to-one")

  out_tbl <- out_tbl |>
    dplyr::mutate(
      valueset_id = stringr::str_replace(value_id, "str:value:", "str:valueset:"),
      valueset_id = stringr::str_replace(valueset_id, ":[^:]*$", "")
    )

  out_tbl <- dplyr::left_join(out_tbl, valueset_info, by = c("valueset_id"), relationship = "many-to-one")
  out_tbl <- dplyr::left_join(out_tbl, values_info, by = c("value_id"), relationship = "one-to-one")

  if (nrow(out_tbl |> dplyr::filter(is.na(value_label))) > 0) {
    warning("Value label missing for some values. For MSOA/LSOA/OA data use value_code instead")
  }

  dplyr::mutate(out_tbl, value_code = stringr::str_extract(value_id, "[^:]*$"))
}
