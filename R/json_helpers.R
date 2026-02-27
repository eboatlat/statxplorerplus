# JSON helpers -----------------------------------------------------------------

#' Correct JSON formatting quirks after export
#'
#' Stat-Xplore exports occasionally contain some awkward constructs (e.g.
#' `[true]` / `[false]`). This helper normalises those patterns and optionally
#' forces all `total` flags to `FALSE` to remove total rows.
#'
#' @param .input_file Path to the JSON file to read.
#' @param .output_file Path to write the corrected JSON.
#' @param remove_total_rows If `TRUE`, force totals off by replacing `true` with
#'   `false` throughout the JSON text.
#'
#' @return Invisibly returns `NULL`. Writes a corrected JSON file to disk.
#' @keywords internal
correct_json_format <- function(.input_file, .output_file,
                                remove_total_rows = TRUE) {
  file_content <- readLines(.input_file, warn = FALSE)
  json_text <- paste(file_content, collapse = "
")
  json_text <- gsub("\\[true\\]", "true", json_text)
  json_text <- gsub("\\[false\\]", "false", json_text)

  if (remove_total_rows) {
    json_text <- gsub("true", "false", json_text)
  }

  json_text <- remove_brackets_between_database_and_measures(json_text)
  writeLines(json_text, .output_file)
  invisible(NULL)
}

#' Remove brackets between `database` and `measures`
#'
#' Some exported JSON contains an unexpected bracketed section between the
#' `"database"` and `"measures"` keys. This helper strips square brackets from
#' that section using a regex.
#'
#' @param .input_string A JSON string.
#'
#' @return A JSON string with the bracketed section corrected.
#' @keywords internal
remove_brackets_between_database_and_measures <- function(.input_string) {
  input_string <- .input_string
  pattern <- "(?s)\\\"database\\\"(.*?)\\\"measures\\\""
  matches <- regmatches(input_string, gregexpr(pattern, input_string, ignore.case = TRUE, perl = TRUE))[[1]]

  for (match in matches) {
    substr_between <- sub(pattern, "\\1", match, ignore.case = TRUE, perl = TRUE)
    replaced <- gsub("\\[|\\]", "", substr_between, perl = TRUE)
    input_string <- gsub(substr_between, replaced, input_string, fixed = TRUE)
  }

  input_string
}

#' Export a JSON spec with post-processing corrections
#'
#' Writes a JSON spec to disk (pretty-printed) and then runs
#' [correct_json_format()] to normalise formatting quirks. This is also used to
#' optionally remove total rows by forcing all `total` flags to `FALSE`.
#'
#' @param .json A list representing a Stat-Xplore JSON query/spec.
#' @param .output_path File path to write the JSON.
#' @param remove_total_rows If `TRUE`, force totals off after writing.
#'
#' @return Invisibly returns `NULL`. Writes a JSON file to `.output_path`.
#' @export
export_json <- function(.json, .output_path,
                        remove_total_rows = TRUE) {
  jsonlite::write_json(.json, .output_path, auto_unbox = FALSE, pretty = TRUE)
  correct_json_format(
    .input_file = .output_path,
    .output_file = .output_path,
    remove_total_rows = remove_total_rows
  )
  invisible(NULL)
}

#' Remove total rows from a JSON spec/query file
#'
#' Convenience wrapper around [export_json()] that reads a JSON file, forces all
#' totals off, and writes the corrected JSON to a new file.
#'
#' @param .input_path Path to the input JSON file.
#' @param .output_path Path to write the output JSON file.
#'
#' @return Invisibly returns `NULL`. Writes a JSON file to `.output_path`.
#' @export
remove_total_rows <- function(.input_path, .output_path) {
  json_text <- readLines(.input_path, warn = FALSE)
  data <- jsonlite::fromJSON(paste0(json_text, collapse = "
"))
  export_json(data, .output_path = .output_path, remove_total_rows = TRUE)
  invisible(NULL)
}
