#' Correct JSON formatting quirks
#' @export
correct_json_format<- function(.input_file, .output_file) {
  file_content <- readLines(.input_file, warn = FALSE)
  json_text <- paste(file_content, collapse = "\n")
  json_text <- gsub("\\[true\\]", "true", json_text)
  json_text <- gsub("\\[false\\]", "false", json_text)
  json_text<- gsub("true", "false", json_text)
  json_text<-remove_brackets_between_database_and_measures(json_text)
  write(json_text, .output_file)
}

#' Remove brackets between database and measures
#' @export
remove_brackets_between_database_and_measures <- function(.input_string) {
  input_string<-.input_string
  pattern <- "(?s)\\\"database\\\"(.*?)\\\"measures\\\""
  matches <- regmatches(input_string, gregexpr(pattern, input_string, ignore.case = TRUE, perl = TRUE))[[1]]
  for (match in matches) {
    substr_between <- sub(pattern, "\\1", match, ignore.case = TRUE, perl = TRUE)
    replaced <- gsub("\\[|\\]", "", substr_between, perl = TRUE)
    input_string <- gsub(substr_between, replaced, input_string, fixed = TRUE)
  }
  input_string
}

#' Export a JSON spec with corrections
#' @export
export_json<-function(.json,.output_path){
  jsonlite::write_json(.json,.output_path, auto_unbox = TRUE, pretty = TRUE)
  correct_json_format(.input_file = .output_path, .output_file = .output_path)
}
