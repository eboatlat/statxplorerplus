#' Update a spec table to include newer dates
#' @export
update_spec_table_to_latest_data<-function(.input_tbl){
  tbl<-add_labels_and_locations_to_spec_table(.input_tbl)
  tbl<-dplyr::mutate(tbl, date_value=lubridate::my(value_label))
  date_tbl<-tbl|> tidyr::drop_na(date_value)|> dplyr::mutate(max_date_value=max(date_value))
  date_field_label<-tbl|> tidyr::drop_na(date_value)|> dplyr::distinct(field_label)|> dplyr::pull()
  if(length(date_field_label)!=1) stop("Can not detect a date column")
  date_field_location<-tbl|> dplyr::filter(field_label==date_field_label)|> dplyr::distinct(field_location)|> dplyr::pull()
  avail_values<-get_target_type_info_below(.url=date_field_location, .target_types="VALUE")|> dplyr::rename_with(~paste0("value_",.x))
  matched_dates<-dplyr::bind_rows(avail_values, date_tbl)|> dplyr::mutate(date_value=lubridate::my(value_label), max_exist_date_value=max(max_date_value,na.rm=TRUE))
  newer_dates<-matched_dates|> dplyr::filter(date_value>max_exist_date_value)|> dplyr::select(dplyr::starts_with("value_"))
  info<-date_tbl|> dplyr::select(-dplyr::starts_with("value_"), -dplyr::contains("date_"))|> dplyr::distinct()
  if(nrow(info)!=1) stop("Can't detect right information on dates")
  newer_dates_tbl<-dplyr::cross_join(info, newer_dates)
  message("Adding additional dates"); print(newer_dates)
  .input_tbl|> dplyr::bind_rows(newer_dates_tbl)|> dplyr::select(dplyr::ends_with("_id"))
}
