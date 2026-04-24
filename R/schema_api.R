# Schema API helpers -----------------------------------------------------------

# Constants -------------------------------------------------------------------

#' Stat-Xplore API schema endpoint
#' @keywords internal
SCHEMA_URL <- "https://stat-xplore.dwp.gov.uk/webapi/rest/v1/schema"

# Functions -------------------------------------------------------------------

#' Fetch schema information (supports pagination via `Link` header)
#'
#' Calls a Stat-Xplore schema URL and returns the parsed response as a tibble.
#' Some schema endpoints return a `children` array. When present, this function
#' flattens the response by cross-joining the parent record to each child and
#' prefixing child columns with `child_`.
#'
#' If the endpoint is paginated, Stat-Xplore supplies a `Link` header containing
#' a `rel="next"` URL. This function follows that URL up to `pages` times.
#'
#' @param url A schema URL to fetch (e.g. a database or field location).
#' @param pages Maximum number of pages to traverse when following `rel="next"`.
#'
#' @return A tibble containing flattened schema information.
#' @export
get_schema_info <- function(url, pages = 10) {
  api_key <- get_api_key()
  full_out <- tibble::tibble()

  for (page in 1:pages) {
    response <- httr::GET(url, httr::add_headers("APIKey" = api_key))

    if (httr::status_code(response) != 200) {
      stop(paste("API request failed with status code:", httr::status_code(response)))
    }

    data <- httr::content(response, as = "text", encoding = "UTF-8")
    data <- jsonlite::fromJSON(data, flatten = TRUE)

    parent_data <- data[names(data) != "children"]
    parent_data <- dplyr::as_tibble(parent_data)
    out <- janitor::clean_names(parent_data)

    if ("children" %in% names(data)) {
      child_data <- data$children
      if (is.data.frame(child_data) && ncol(child_data) > 0) {
        child_data <- dplyr::as_tibble(child_data) |>
          dplyr::rename_with(~ paste0("child_", .x))

        out <- parent_data |>
          dplyr::cross_join(child_data) |>
          janitor::clean_names()
      }
    }

    full_out <- dplyr::bind_rows(full_out, out)

    link_header <- response$headers[["link"]]
    if (is.null(link_header) || !stringr::str_detect(link_header, 'rel="next"')){
      break
    }
    matches <- stringr::str_match(link_header, "<([^>]+)>; rel=\"next\"")
    if (is.na(matches[2])) {
      break
    }

    url <- matches[2]
    if (page == pages) warning("Warning: URL contains more than specified pages.")
  }

  full_out
}

#' Get the next level of schema children below a URL
#'
#' Convenience wrapper around [get_schema_info()] that returns only child rows,
#' with column names de-prefixed from `child_` to the base names.
#'
#' @param url A schema URL to fetch.
#' @param error_if_next_level_empty If `TRUE` (default), error when the response
#'   contains no `children`. If `FALSE`, return an empty tibble.
#' @param pages Maximum number of pages to follow (passed to [get_schema_info()]).
#'   Increase this for endpoints with large numbers of children (e.g. LSOA
#'   geographies).
#'
#' @return A tibble of child records (with columns such as `id`, `label`,
#'   `type`, `location`, ...), or an empty tibble.
#' @export
get_next_level_info <- function(url, error_if_next_level_empty = TRUE,
                                pages = 10) {
  schema_info <- get_schema_info(url, pages = pages)
  out <- schema_info |> dplyr::select(dplyr::contains("child"))

  if (ncol(out) == 0) {
    if (error_if_next_level_empty) stop("No info below this level")
    return(tibble::tibble())
  }

  out<-out|>
    dplyr::rename_with( ~ stringr::str_replace(.x, "child_", ""), .cols = dplyr::everything())
  return(out)
}

#' List available databases
#'
#' Walks the schema tree starting at `base_path` and returns records whose
#' `type` equals `"DATABASE"`.
#'
#' @param base_path Schema root URL to start from. Defaults to [SCHEMA_URL].
#'
#' @return A tibble of databases (including `id`, `label`, and `location`).
#' @export
list_databases <- function(base_path = SCHEMA_URL) {
  paths <- base_path
  databases <- tibble::tibble()

  for (i in 1:10) {
    next_level <- purrr::map(paths, ~ get_next_level_info(.x, error_if_next_level_empty = FALSE)) |>
      dplyr::bind_rows()

    paths <- next_level |> dplyr::filter(type == "FOLDER") |> dplyr::pull(location)

    new_databases <- next_level |> dplyr::filter(type == "DATABASE")
    databases <- dplyr::bind_rows(databases, new_databases)

    if (is.vector(paths) && length(paths) == 0) break
  }

  databases
}
