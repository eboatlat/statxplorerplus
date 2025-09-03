#' Fetch schema info (with pagination via Link header)
#' @param url Starting URL to fetch.
#' @param pages Maximum pages to traverse.
#' @return Tibble of schema info (flattened).
#' @export
get_schema_info <- function(url, pages = 10) {
  api_key <- get_api_key()
  full_out <- tibble::tibble()
  for (page in 1:pages) {
    response <- httr::GET(url, httr::add_headers("APIKey" = api_key))
    if (httr::status_code(response) != 200) stop(paste("API request failed with status code:", httr::status_code(response)))
    data <- httr::content(response, as = "text", encoding = "UTF-8")
    data <- jsonlite::fromJSON(data, flatten = TRUE)
    parent_data <- data[names(data) != "children"]
    parent_data <- dplyr::as_tibble(parent_data)
    out <- janitor::clean_names(parent_data)
    if ("children" %in% names(data)) {
      child_data <- data$children
      if (is.data.frame(child_data) && ncol(child_data) > 0) {
        child_data <- dplyr::as_tibble(child_data) |>
          dplyr::rename_with(~paste0("child_", .x))
        out <- parent_data |>
          dplyr::cross_join(child_data) |>
          janitor::clean_names()
      }
    }
    full_out <- dplyr::bind_rows(full_out, out)
    link_header <- response$headers[["link"]]
    if (is.null(link_header) || !stringr::str_detect(link_header, 'rel="next"')) break
    matches <- stringr::str_match(link_header, "<([^>]+)>; rel=\"next\"")
    if (is.na(matches[2])) break
    url <- matches[2]
    if (page == pages) warning("Warning: URL contains more than specified pages.")
  }
  full_out
}

#' Get next-level info below a schema URL
#' @export
get_next_level_info<-function(url, error_if_next_level_empty=TRUE){
  schema_info<-get_schema_info(url)
  out<-schema_info|> dplyr::select(contains("child"))
  if(ncol(out)==0){
    if(error_if_next_level_empty) stop("No info below this level") else return(tibble::tibble())
  }
  dplyr::rename_with(out, ~stringr::str_replace(.x,"child_",""), .cols=dplyr::everything())
}

#' List databases from the configured base URL
#' @export
list_databases <- function(base_path = get_base_url()) {
  paths <- get_base_url()
  databases <- tibble::tibble()
  for (i in 1:10) {
    next_level <- purrr::map(paths, ~get_next_level_info(.x, error_if_next_level_empty = FALSE)) |> dplyr::bind_rows()
    paths <- next_level |> dplyr::filter(type == "FOLDER") |> dplyr::pull(location)
    new_databases <- next_level |> dplyr::filter(type == "DATABASE")
    databases <- dplyr::bind_rows(databases, new_databases)
    if (is.vector(paths) && length(paths) == 0) break
  }
  databases
}
