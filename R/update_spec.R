#' Update a spec table to include newer dates
#'
#' Given a tidy spec table (as used by [fetch_data_from_spec_table()]), this
#' function detects the date field (by attempting to parse `value_label` as a
#' month-year using [lubridate::my()] or year-month using [lubridate::ym()])
#' and appends any additional available date values (can select to only add
#' newer dates.
#'
#' The returned table contains only `*_id` columns, ready to be converted back
#' into a JSON spec via [convert_spec_table_to_list()].
#'
#' @param .input_tbl A spec table with at least `database_id`, `measure_id`,
#'   `field_id`, and `value_id`.
#' @param .add_only_newer_dates A binary choice as to whether only add in new data
#' @return A spec table with extra rows for newly available dates.
#' @export
update_spec_table_to_latest_data <- function(.input_tbl,
                                             .add_only_newer_dates = TRUE) {
  tbl <- .input_tbl
  if (!"value_label" %in% names(tbl)) {
    tbl <- add_labels_and_locations_to_spec_table(tbl)
  }
  # test if column is a date
  date_tbl <- tbl |>
    # pre-filter for a quarter or month or date in the field
    dplyr::filter(stringr::str_detect(field_id, "(?i)date|quarter|month|time")) |>
    dplyr::mutate(
      date_value_temp = lubridate::my(value_label),
      date_value = dplyr::if_else(
        is.na(date_value_temp),
        lubridate::ym(value_label),
        date_value_temp
      )
    ) |>
    dplyr::select(-date_value_temp)

  date_tbl <- date_tbl |>
    tidyr::drop_na(date_value) |>
    dplyr::mutate(
      max_date_value = max(date_value),
      exist_data = TRUE
    )

  date_field_label <- date_tbl |>
    tidyr::drop_na(date_value) |>
    dplyr::distinct(field_label) |>
    dplyr::pull()

  if (length(date_field_label) != 1) stop("Can not detect a date column")

  date_field_location <- tbl |>
    dplyr::filter(field_label == date_field_label) |>
    dplyr::distinct(field_location) |>
    dplyr::pull()

  avail_values <- get_target_type_info_below(
    .url = date_field_location,
    .target_types = "VALUE"
  ) |>
    dplyr::rename_with(~ paste0("value_", .x))

  matched_dates <- dplyr::bind_rows(avail_values, date_tbl) |>
    dplyr::mutate(
      date_value_temp = lubridate::my(value_label),
      date_value = dplyr::if_else(
        is.na(date_value_temp),
        lubridate::ym(value_label),
        date_value_temp
      ),
      max_exist_date_value = max(max_date_value, na.rm = TRUE),
      exist_data = dplyr::if_else(is.na(exist_data), FALSE, TRUE)
    )

  dates_to_add <- matched_dates
  # only add newer dates if selected
  if (.add_only_newer_dates) {
    dates_to_add <- dates_to_add |>
      dplyr::filter(date_value > max_exist_date_value)
  } else {
    dates_to_add <- dates_to_add |>
      dplyr::filter(exist_data == FALSE)
  }
  dates_to_add <- dates_to_add |>
    dplyr::select(dplyr::starts_with("value_"))

  info <- date_tbl |>
    dplyr::select(-dplyr::starts_with("value_"), -dplyr::contains("date_")) |>
    dplyr::distinct()

  if (nrow(info) != 1) stop("Can't detect right information on dates")

  add_dates_tbl <- dplyr::cross_join(info, dates_to_add)

  message("Adding additional dates")
  print(add_dates_tbl)

  .input_tbl |>
    dplyr::bind_rows(add_dates_tbl) |>
    dplyr::select(dplyr::ends_with("_id"), dplyr::ends_with("_label")) |>
    dplyr::distinct()
}
