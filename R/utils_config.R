#' Set and get configuration
#'
#' Defaults to the official Stat-Xplore base URL.
#'
#' @param api_key Character. API key for authenticated calls (or set env var `STATXPLORE_API_KEY`).
#' @param base_url Character. Base schema URL. Defaults to "https://stat-xplore.dwp.gov.uk/webapi/rest/v1".
#' @return Invisibly returns a named list of the values set.
#' @export
set_statxplore_config <- function(api_key = NULL,
                                  base_url = "https://stat-xplore.dwp.gov.uk/webapi/rest/v1") {
  if (!is.null(api_key)) options(statxplore.api_key = api_key)
  options(statxplore.base_url = base_url)
  invisible(list(api_key = getOption("statxplore.api_key"), base_url = getOption("statxplore.base_url")))
}

#' @rdname set_statxplore_config
#' @export
get_api_key <- function() {
  opt <- getOption("statxplore.api_key", default = NA_character_)
  if (!is.na(opt) && nzchar(opt)) return(opt)
  env <- Sys.getenv("STATXPLORE_API_KEY", "")
  if (!nzchar(env)) stop("API key not found. Set with set_statxplore_config(api_key=...) or env var STATXPLORE_API_KEY.", call. = FALSE)
  env
}

#' @rdname set_statxplore_config
#' @export
get_base_url <- function() {
  getOption("statxplore.base_url", default = "https://stat-xplore.dwp.gov.uk/webapi/rest/v1")
}
