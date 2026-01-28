#' @keywords internal
put_grouped_variable_mapping_into_table<-function(.mapping, .fieldname){
  full_tbl<-tibble::tibble()
  for(i in 1:length(.mapping)){
    values<-.mapping[[i]]
    groupname<-paste0("group",i)
    tbl<-tibble::tibble(value_group=groupname, value=values)
    full_tbl<-dplyr::bind_rows(full_tbl, tbl)
  }
  dplyr::mutate(full_tbl, field=.fieldname)
}

#' Convert a JSON spec to a tidy table
#' @param .json_path Path to the JSON file.
#' @return Tibble with ids per field/value (incl. value_group when grouped).
#' @export
convert_json_to_spec_table<-function(.json_path){
  json_text<-readLines(.json_path, warn=FALSE)
  data<-jsonlite::fromJSON(paste0(json_text, collapse="\n"))
  database<-data$database
  measure<-data$measures
  if(length(measure)>1) stop("More than one measure in JSON, conversion requires only one measure")
  fields<-as.vector(data$dimensions)
  mappings<-purrr::map(fields, ~data$recodes[[.x]]$map)
  grouped_flag<-unlist(purrr::map(mappings, is.list))
  grouped_mappings<-mappings[grouped_flag]; grouped_fields<-fields[grouped_flag]
  ungrouped_mappings<-mappings[!grouped_flag]; ungrouped_fields<-fields[!grouped_flag]
  ungrouped_tbl<-purrr::map2(ungrouped_mappings, ungrouped_fields, ~tibble::tibble(value=as.vector(unlist(.x)), field=.y, value_group=NA_character_)) |> dplyr::bind_rows()
  if(length(grouped_fields)>0) warning("Grouped variable provided, group names will be automatically created.")
  grouped_tbl<-purrr::map2(grouped_mappings, grouped_fields, put_grouped_variable_mapping_into_table) |> dplyr::bind_rows()
  dplyr::bind_rows(grouped_tbl, ungrouped_tbl) |>
    dplyr::mutate(database_id=database, measure_id=measure) |>
    dplyr::rename(field_id=field, value_id=value)
}

#' @keywords internal
construct_mapping_for_indiv_var<-function(.tbl){
  field <- .tbl |> dplyr::distinct(field_id) |> dplyr::pull()
  if(length(field)>1) stop("Table has more than one value for field column in it.")
  if(!"value_group"%in%names(.tbl)){
    .tbl<-.tbl|>
      dplyr::mutate(value_group=NA)
  }
  groups <- .tbl |> 
      tidyr::drop_na(value_group)|>
      dplyr::distinct(value_group) |> 
      dplyr::pull()
  
  #throw error if there are some nas but not all NAs in group variable
  groups_with_na<-.tbl|>
    dplyr::distinct(value_group) |>
    dplyr::pull()
  
  if(length(groups!=0)&(length(groups_with_na)!=length(groups))){
    stop(paste0("Combination of grouped and non-grouped values for field", field))
  }
  
  if(length(groups)==0){
    values <- .tbl |> dplyr::distinct(value_id) |> dplyr::pull()
    out<- list(map = matrix(values, ncol = 1), total = FALSE)
  } else {
    vals <- lapply(groups, function(g) .tbl |> dplyr::filter(value_group==g) |> dplyr::distinct(value_id) |> dplyr::pull())
    out<- list(map = vals, total = FALSE)
  }
}

#' Convert a tidy table to a list (which is exportable to a json)
#' @export
convert_spec_table_to_list<-function(.table){
  database <- .table |> dplyr::distinct(database_id) |> dplyr::pull()
  if(length(database)>1) stop("Table references more than one database")
  measure <- .table |> dplyr::distinct(measure_id) |> dplyr::pull()
  if(length(measure)>1) stop("Table references more than one measure")
  fields <- .table |> dplyr::distinct(field_id) |> dplyr::pull()
  mappings <- purrr::map(fields, ~.table |> dplyr::filter(field_id==.x) |> construct_mapping_for_indiv_var())
  names(mappings) <- fields
  list(database = database, measures = measure, recodes = mappings, dimensions = matrix(fields, ncol = 1))
}
