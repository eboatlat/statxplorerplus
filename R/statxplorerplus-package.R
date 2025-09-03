#' statxplorerplus: Construct queries to download data from the Stat-Xplore API
#'
#' The statxplorerplus package provides a suite of functions for 
#' constructing queries and downloading data
#' from the Department for Work and Pensions Stat-Xplore API.
#'
#' 
#' #' @keywords internal
"_PACKAGE"
#' @name statxplorerplus
#' @importFrom magrittr %>%
#' @importFrom rlang .data
NULL

# Tell R CMD check about new operators
if(getRversion() >= "2.15.1") {
  utils::globalVariables(c(".", ":="))
}
