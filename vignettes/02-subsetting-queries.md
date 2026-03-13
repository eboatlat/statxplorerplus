
# 2. Subsetting queries

## Overview

A JSON spec exported from Stat-Xplore may contain far more values than
you need for a particular analysis. Rather than sending the full query
to the API, you can convert the JSON to a spec table, filter it down to
only the rows you want, and then fetch just that subset of the data.

This vignette shows how to load a JSON spec, isolate a single age value
(age 16), and download only that slice of the data.

## Step 1 – Load the package and set your API key

``` r
library(statxplorerplus)
library(dplyr)

load_api_key("path/to/apikey.txt")
```

## Step 2 – Convert the JSON to a spec table and add labels

``` r
json_path <- system.file("extdata", "acc_ew_by_single_year_of_age.json",
                         package = "statxplorerplus")

spec_tbl <- convert_json_to_spec_table(json_path) |>
  add_labels_and_locations_to_spec_table()
```

The full spec table contains rows for all 51 single years of age as well
as rows for the geography, employment, and date fields. You can inspect
which fields and values are included:

``` r
spec_tbl |>
  count(field_label)
```

    #> # A tibble: 4 × 2
    #>   field_label                          n
    #>   <chr>                            <int>
    #> 1 Age (bands and single year)         51
    #> 2 Employment Indicator                 3
    #> 3 Month                                3
    #> 4 National - Regional - LA - Wards     2

## Step 3 – Filter to age 16 only

Keep only the row for age 16 from the age field, leaving all other
fields unchanged:

``` r
spec_tbl_age16 <- spec_tbl |>
  filter(
    field_label != "Age (bands and single year)" |
      value_code == "16"
  )

spec_tbl_age16 |>
  select(field_label, value_label, value_code)
```

    #> # A tibble: 9 × 3
    #>   field_label                      value_label       value_code
    #>   <chr>                            <chr>             <chr>
    #> 1 Age (bands and single year)      16                16
    #> 2 Month                            August 2013       201308
    #> 3 Month                            August 2019       201908
    #> 4 Month                            August 2022       202208
    #> 5 National - Regional - LA - Wards England           E92000001
    #> 6 National - Regional - LA - Wards Wales             W92000004
    #> 7 Employment Indicator             Not in employment 0
    #> 8 Employment Indicator             In employment     1
    #> 9 Employment Indicator             Not available     99

The spec table now has just one age row instead of 51, which will make
the API call much faster.

## Step 4 – Fetch the data

``` r
acc_age16 <- fetch_data_from_spec_table(spec_tbl_age16)

acc_age16
```

    #> # A tibble: 18 × 5
    #>    `Age (bands and single year)` Month       `National - Regional - LA - Wards` `Employment Indicator` `Alternative Claimant Count`
    #>    <chr>                         <chr>       <chr>                              <chr>                                         <dbl>
    #>  1 16                            August 2013 England                            Not in employment                               329
    #>  2 16                            August 2013 England                            In employment                                    11
    #>  3 16                            August 2013 England                            Not available                                     0
    #>  4 16                            August 2013 Wales                              Not in employment                                22
    #>  5 16                            August 2013 Wales                              In employment                                     0
    #>  6 16                            August 2013 Wales                              Not available                                     0
    #>  7 16                            August 2019 England                            Not in employment                               322
    #>  8 16                            August 2019 England                            In employment                                    22
    #>  9 16                            August 2019 England                            Not available                                     0
    #> 10 16                            August 2019 Wales                              Not in employment                                34
    #> ...

## Summary

| Step | Code | Purpose |
|----|----|----|
| 1 | `convert_json_to_spec_table()` | Parse JSON → spec table |
| 2 | `add_labels_and_locations_to_spec_table()` | Add human-readable labels |
| 3 | `filter()` | Keep only the values you need |
| 4 | `fetch_data_from_spec_table()` | Fetch the subset from the API |
