
# 5. Updating a spec to the latest available data

## Overview

Stat-Xplore data is updated regularly. A JSON spec you downloaded months
ago will only contain the dates that were available at that time. Rather
than manually editing the JSON every time new data is released,
`update_spec_table_to_latest_data()` queries the Stat-Xplore schema and
appends date values automatically.

This vignette shows the full workflow:

1.  Convert a JSON to a spec table.
2.  Inspect which dates are currently in the spec.
3.  Update the spec to include all available dates not already in the
    spec.
4.  (Optional) add groupings to the updated dates.
5.  Fetch the updated data.

## Step 1 – Load the package and set your API key

``` r
library(statxplorerplus)
library(dplyr)
library(stringr)

load_api_key("path/to/apikey.txt")
```

## Step 2 – Convert the JSON to a spec table and add labels

``` r
json_path <- system.file("extdata", "acc_ew_by_single_year_of_age.json",
                         package = "statxplorerplus")

spec_tbl <- convert_json_to_spec_table(json_path) |>
  add_labels_and_locations_to_spec_table()
```

### Inspect the dates currently in the spec

``` r
spec_tbl |>
  filter(field_label == "Month") |>
  select(value_label)
```

    #> # A tibble: 3 × 1
    #>   value_label
    #>   <chr>
    #> 1 August 2013
    #> 2 August 2019
    #> 3 August 2022

The spec only covers three months. Many other months available in the
database are not included.

## Step 3 – Update to include all available dates

`update_spec_table_to_latest_data()` queries the Stat-Xplore schema for
the date field and appends any date values not already in the spec.

Setting `.add_only_newer_dates = TRUE` only appends dates that are newer
than the latest date already in the spec. Setting it to `FALSE` appends
all available dates not already present, including historical ones.

``` r
spec_tbl_updated <- update_spec_table_to_latest_data(
  spec_tbl,
  .add_only_newer_dates = FALSE
)
```

### Inspect the updated dates

``` r
spec_tbl_updated |>
  filter(field_label == "Month") |>
  select(value_label)
```

    #> # A tibble: 116 × 1
    #>    value_label
    #>    <chr>
    #>  1 August 2013
    #>  2 August 2019
    #>  3 August 2022
    #>  4 January 2013
    #>  5 February 2013
    #>  6 March 2013
    #>  ...

The spec now covers all 116 months available in the database.

## Step 4 – (Optional) add a grouping for the date field

You can classify the updated dates into meaningful periods before
fetching. For example, group by era:

``` r
spec_tbl_updated <- spec_tbl_updated |>
  mutate(
    value_group = case_when(
      field_label == "Month" &
        str_detect(value_label, "2013|2014|2015|2016|2017|2018") ~
          "Pre-2019",
      field_label == "Month" &
        str_detect(value_label, "2019|2020|2021|2022") ~
          "2019 onwards",
      TRUE ~ NA_character_
    )
  )
```

## Step 5 – Fetch the updated data

``` r
acc_updated <- fetch_data_from_spec_table(spec_tbl_updated)

head(acc_updated)
```

    #>   `Age (bands and single year)` `National - Regional - LA - Wards`
    #>   <chr>                         <chr>
    #> 1 16                            England
    #> 2 16                            England
    #> ...

## Saving the updated spec back to JSON

After updating, you can export the revised spec so it can be reused or
shared without needing to re-run the update step:

``` r
updated_list <- convert_spec_table_to_list(spec_tbl_updated)

export_json(
  .json        = updated_list,
  .output_path = "path/to/acc_ew_by_single_year_of_age_updated.json"
)
```

## Summary

| Step | Function | Purpose |
|----|----|----|
| 1 | `convert_json_to_spec_table()` | Parse JSON → spec table |
| 2 | `add_labels_and_locations_to_spec_table()` | Add human-readable labels |
| 3 | `update_spec_table_to_latest_data()` | Append available date values from schema |
| 4 | `mutate(value_group = ...)` | *(optional)* group the updated dates |
| 5 | `fetch_data_from_spec_table()` | Fetch data including new dates |
| 6 | `convert_spec_table_to_list()` + `export_json()` | *(optional)* save updated spec |
