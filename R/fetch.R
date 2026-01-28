### Functions for making and receiving http requests

# Constants -------------------------------------------------------------------

URL_INFO <- "https://stat-xplore.dwp.gov.uk/webapi/rest/v1/info"
URL_TABLE <- "https://stat-xplore.dwp.gov.uk/webapi/rest/v1/table"

# Functions -------------------------------------------------------------------

#' Send an http request with a query and return the response
#'
#' \code{request_table} sends a query to the table endpoint, checks the
#' response, parses the response text as json, and returns the parsed data. If
#' the query syntax is not valid or the request fails for any other reason an
#' error is raised with the response text.
#'
#' @param query A valid Stat-Xplore query as a string.
#' @param timeout Length to wait before timing out (seconds)
#' @return A list of the query results as parsed json.
#' @export

request_table <- function(query,
                          timeout = 600) {

    # Get api key from cache
    api_key <- get_api_key()

    # Set headers
    headers <- httr::add_headers(
        "APIKey" = api_key,
        "Content-Type" = "application/json")

    # POST and return
    tryCatch({
        response <- httr::POST(
            URL_TABLE,
            headers,
            body = query,
            encode = "form",
            timeout = timeout)},
        error = function(c) {
            stop("Could not connect to Stat-Xplore: the server may be down")
        })

    # Extract the text
    response_text <- httr::content(response, as = "text", encoding = "utf-8")

    # If the server returned an error raise it with the response text
    if (response$status_code != 200) {
        stop(stringr::str_glue(
            "The server responded with the error message: {response_text}"))
    }

    # Process the JSON, and return
    jsonlite::fromJSON(response_text, simplifyVector = FALSE)
}

#' Send a table query and return the results
#'
#' \code{fetch_table} sends a query to the table endpoint and returns the
#' response as a list containing the results. The results include a dataframe
#' of tidy data for each measure requested by the query.
#'
#' A query can be provided as a string or can be loaded from a file using the
#' \code{filename} argument. This is sometimes convenient as Stat-Xplore
#' queries can be large and are most easily produced using the table builder
#' tool on the website, which exports queries as json text files.
#'
#' Stat-Xplore returns one set of results for each measure included in a query.
#' Each set of results includes data for different measures on the same set of
#' observations.
#'
#' The list of results has the following structure:
#'
#' measures - the names of the measures for each dataset (character)
#' fields - the names of categorical variables included in the data (character)
#' items - the names of the categories or levels within each field (list)
#' uris - the uris of the categories or levels within each field (list)
#' dfs - a dataframe for each measure with the data in long form (list)
#'
#' @param query Stat-Xplore query as a string.
#' @param filename The path to a text file containing a Stat-Xplore query.
#'   This argument is not required but has priority: if a \code{filename} is
#'   provided, the \code{query} argument is ignored.
#' @param custom A named list of character vectors. Each name/value pair
#'   indicates the item labels to use for the field with the given name when
#'   constructing the results dataframes. It is necessary to specify item
#'   labels explicitly using this argument when your query uses custom
#'   aggregate variables, as the number of variables in the results will not
#'   agree with the number of variables shown in the metadata.
#' @param timeout Length to wait before timing out (seconds)
#' @param only_keep_data Whether to only output the dataset
#' @param drop_total_rows Whether to drop total rows (defaults to keeping them)
#' @return A list containing the results of the query, with one item per cube.
#' @export

fetch_table <- function(query, filename = NULL, custom = NULL,
                        timeout = 600,
                        only_keep_data=T,
                        drop_total_rows=F) {

    # Read the query from a file if given
    if (! is.null(filename)) query <- readr::read_file(filename)
    
    #drop the rows with totals in them by importing and re-exporting
    if(drop_total_rows==T){
      tmpfile<-tempfile()
      json_list<-jsonlite::fromJSON(query)
      #export_json function automatically deletes total rows
      export_json(json_list,tmpfile)
      query<-readr::read_file(tmpfile)
    }
    
    # Send the query and get the response
    response_json <- request_table(query,
                                   timeout=timeout)

    # Extract results
    out<-extract_results(response_json, custom)
    
    if(only_keep_data){
      out<-out$dfs[[1]]
    }
    return(out)
}


#'@export 
fetch_data_from_spec_table<-function(spec_table,
                                     timeout=600,
                                     only_keep_data=T){
  #arrange spec table so custom mappings will work 
  if(!"value_group"%in%names(spec_table)){
    spec_table<-spec_table|>
      dplyr::mutate(value_group=NA)
  }
  spec_table<-spec_table|>
    dplyr::arrange(field_id,value_group)
  
  mapping_df<-spec_table|>
    tidyr::drop_na(value_group)|>
    dplyr::distinct(value_group,field_label)
  
  mapping_field_names<-mapping_df|>
    dplyr::distinct(field_label)|>
    dplyr::pull()
  
  mapping<-purrr::map(mapping_field_names,
                      ~mapping_df|>
                        dplyr::filter(field_label==.x)|>
                        dplyr::pull(value_group))
  names(mapping)<-mapping_field_names
  
  temp_path<-tempfile(fileext=".json")
  
  #now export the spec_table to the temp path
  spec_list<-convert_spec_table_to_list(spec_table)
  export_json(spec_list,temp_path)
  
  #and fetch from that temp_path
  out<-fetch_table(filename=temp_path,
                   custom=mapping,
                   timeout=timeout,
                   only_keep_data=only_keep_data)
  
  return(out)
  
}
