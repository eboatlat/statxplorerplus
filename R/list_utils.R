#' Drop empty lists recursively
#' @param x A list (possibly nested).
#' @return The same list structure with zero-length lists removed.
drop_empty_lists <- function(x) {
  x <- Filter(function(el) !(is.list(el) && length(el) == 0), x)
  lapply(x, function(el) if (is.list(el)) drop_empty_lists(el) else el)
}

#' Convert a list-column to strings
#' @param df A data.frame or tibble.
#' @param list_col_name Name of the list-column.
#' @param sep Separator used to collapse list elements.
#' @return `df` with the column replaced by character values.
convert_list_column_to_string <- function(df, list_col_name, sep = "_") {
  list_col <- df[[list_col_name]]
  string_col <- vapply(list_col, function(x) {
    if (is.null(x)) NA_character_ else if (length(x) == 0) "" else paste(x, collapse = sep)
  }, character(1))
  df[[list_col_name]] <- string_col
  df
}
