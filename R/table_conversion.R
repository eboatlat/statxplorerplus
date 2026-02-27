# Spec table <-> JSON conversion ------------------------------------------------

#' Expand a grouped mapping in list format into a tidy specification table or "spec table"
#' @param .mapping A list where each element is a character vector of value ids.
#' @param .fieldname Field id to attach to the output.
#' @return A tibble with columns `value_group`, `value`, and `field`.
#' @keywords internal
put_grouped_variable_mapping_into_table <- function(.mapping, .fieldname) {
  full_tbl <- tibble::tibble()
  for (i in seq_along(.mapping)) {
    values <- .mapping[[i]]
    groupname <- paste0("group", i)
    tbl <- tibble::tibble(value_group = groupname, value = values)
    full_tbl <- dplyr::bind_rows(full_tbl, tbl)
  }
  dplyr::mutate(full_tbl, field = .fieldname)
}


#' Convert a JSON spec file to a tidy spec table
#'
#' Reads a Stat-Xplore JSON query/spec file and converts it to a table where
#' each row corresponds to a single field/value selection. Grouped recodes are
#' supported; when encountered, group names are auto-generated (`group1`,
#' `group2`, ...).
#'
#' @param .json_path Path to a JSON spec file exported from Stat-Xplore.
#'
#' @return A tibble referred to as "spec table" with columns `database_id`, `measure_id`, `field_id`,
#'   `value_id`, and (when grouped recodes exist) `value_group`.
#' @export
convert_json_to_spec_table <- function(.json_path) {
  json_text <- readLines(.json_path, warn = FALSE)
  data <- jsonlite::fromJSON(paste0(json_text, collapse = "
"))

  database <- data$database
  measure <- data$measures
  if (length(measure) > 1) stop("More than one measure in JSON, conversion requires only one measure")

  fields <- as.vector(data$dimensions)
  mappings <- purrr::map(fields, ~ data$recodes[[.x]]$map)

  grouped_flag <- unlist(purrr::map(mappings, is.list))
  grouped_mappings <- mappings[grouped_flag]
  grouped_fields <- fields[grouped_flag]

  ungrouped_mappings <- mappings[!grouped_flag]
  ungrouped_fields <- fields[!grouped_flag]

  ungrouped_tbl <- purrr::map2(
    ungrouped_mappings,
    ungrouped_fields,
    ~ tibble::tibble(value = as.vector(unlist(.x)), field = .y, value_group = NA_character_)
  ) |>
    dplyr::bind_rows()

  if (length(grouped_fields) > 0) warning("Grouped variable provided, group names will be automatically created.")

  grouped_tbl <- purrr::map2(grouped_mappings, grouped_fields, put_grouped_variable_mapping_into_table) |>
    dplyr::bind_rows()

  out<-dplyr::bind_rows(grouped_tbl, ungrouped_tbl) |>
    dplyr::mutate(database_id = database, measure_id = measure) |>
    dplyr::rename(field_id = field, value_id = value)
  
  #pull out valueset_id too
  out<-out|>
    dplyr::mutate(
      valueset_id = stringr::str_replace(value_id, "str:value:", "str:valueset:"),
      valueset_id = stringr::str_replace(valueset_id, ":[^:]*$", ""))
  return(out)
}

#' Build a Stat-Xplore recode mapping for a single field
#'
#' @param .tbl A "spec table" subset for a single `field_id`.
#' @return A list compatible with the Stat-Xplore JSON spec format for one
#'   field, with elements `map` and `total`.
#' @keywords internal
construct_mapping_for_indiv_var <- function(.tbl) {
  field <- .tbl |> dplyr::distinct(field_id) |> dplyr::pull()
  if (length(field) > 1) stop("Table has more than one value for field column in it.")

  if (!"value_group" %in% names(.tbl)) {
    .tbl <- .tbl |> dplyr::mutate(value_group = NA_character_)
  }

  groups <- .tbl |>
    tidyr::drop_na(value_group) |>
    dplyr::distinct(value_group) |>
    dplyr::pull()

  # Throw error if there are some NAs but not all NAs in group variable
  groups_with_na <- .tbl |>
    dplyr::distinct(value_group) |>
    dplyr::pull()

  if ((length(groups) != 0) && (length(groups_with_na) != length(groups))) {
    stop(paste0("Combination of grouped and non-grouped values for field ", field))
  }

  if (length(groups) == 0) {
    values <- .tbl |> dplyr::distinct(value_id) |> dplyr::pull()
    out <- list(map = matrix(values, ncol = 1), total = FALSE)
  } else {
    vals <- lapply(
      groups,
      function(g) .tbl |>
        dplyr::filter(value_group == g) |>
        dplyr::distinct(value_id) |>
        dplyr::pull()
    )
    out <- list(map = vals, total = FALSE)
  }

  out
}

#' Construct a mapping of grouped custom variables from a "spec table"
#
#'
#' Takes grouped recodes are supported via a `value_group` column. Where `value_group`
#' is present, the function constructs the `custom` mapping needed by
#' [extract_results()] so returned item labels align with the grouped query.
#'
#' @param spec_table A tibble/data frame with (at minimum) `database_id`,
#'   `measure_id`, `field_id`, and `value_id`. A `value_group` column may be
#'   present for grouped recodes. If no `value_group` column returns NULL,
#'
#' @return A named list which can be input as `custom` input for [fetch_table()]
#' @export
construct_custom_var_mapping_from_spec_table<- function(spec_table) {
  
  # Arrange spec table so custom mappings will work
  if (!"value_group" %in% names(spec_table)) {
    spec_table <- spec_table |>
      dplyr::mutate(value_group = NA_character_)
  }
  
  spec_table <- spec_table |>
    dplyr::arrange(field_id, value_group)
  
  mapping_df <- spec_table |>
    tidyr::drop_na(value_group) |>
    dplyr::distinct(value_group, field_label)
  
  mapping_field_names <- mapping_df |>
    dplyr::distinct(field_label) |>
    dplyr::pull()
  
  mapping <- purrr::map(
    mapping_field_names,
    ~ mapping_df |>
      dplyr::filter(field_label == .x) |>
      dplyr::pull(value_group)
  )
  names(mapping) <- mapping_field_names
  
  return(mapping)
}


#' Convert a tidy "spec table" to a list suitable for JSON export
#'
#' The returned list matches the Stat-Xplore JSON spec structure and can be
#' written using [export_json()].
#' 
#' Note that if the spec table has information on the grouping of values that is lost 
#' through this transformation. 
#'
#' @param .table A spec table with at least `database_id`, `measure_id`,
#'   `field_id`, and `value_id` columns. Optional `value_group` is used to
#'   create grouped recodes.
#'
#' @return A list with elements `database`, `measures`, `recodes`, and
#'   `dimensions`.
#' @export
convert_spec_table_to_list <- function(.table) {
  database <- .table |> dplyr::distinct(database_id) |> dplyr::pull()
  if (length(database) > 1) stop("Table references more than one database")

  measure <- .table |> dplyr::distinct(measure_id) |> dplyr::pull()
  if (length(measure) > 1) stop("Table references more than one measure")

  fields <- .table |> dplyr::distinct(field_id) |> dplyr::pull()
  mappings <- purrr::map(fields, ~ .table |> dplyr::filter(field_id == .x) |> construct_mapping_for_indiv_var())
  names(mappings) <- fields

  list(
    database = database,
    measures = measure,
    recodes = mappings,
    dimensions = matrix(fields, ncol = 1)
  )
}
