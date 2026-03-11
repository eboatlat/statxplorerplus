
# 4. Updating a spec to the latest available data

## Overview

Stat-Xplore data is updated regularly. A JSON spec you downloaded months
ago will only contain the dates that were available at that time. Rather
than manually editing the JSON every time new data is released,
`update_spec_table_to_latest_data()` queries the Stat-Xplore schema and
appends all newer date values automatically.

This vignette shows the full workflow:

1.  Convert a JSON to a spec table.
2.  Inspect which dates are currently in the spec.
3.  Update the spec to include all newer dates.
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
json_path <- "path/to/acc_ew_by_single_year_of_age_pre19.json"

spec_tbl <- convert_json_to_spec_table(json_path) |>
  add_labels_and_locations_to_spec_table()
```

### Inspect the dates currently in the spec

``` r
spec_tbl |>
  filter(field_label == "Month") |>
  select(value_label, value_code)
```

    #> # A tibble: 3 × 2
    #>   value_label  value_code
    #>   <chr>        <chr>
    #> 1 August 2013  201308
    #> 2 August 2019  201908
    #> 3 August 2022  202208

The spec only covers three months. Any data published after August 2022
is missing.

## Step 3 – Update to latest available dates

`update_spec_table_to_latest_data()` queries the Stat-Xplore schema for
the date field, finds all available values, and appends those that are
newer than the latest date already in the spec.

``` r
spec_tbl_updated <- update_spec_table_to_latest_data(
  spec_tbl,
  # default: only appends dates newer than existing
  .add_only_newer_dates = TRUE
)
```

### Inspect the updated dates

``` r
spec_tbl_updated |>
  filter(field_label == "Month") |>
  select(value_label, value_code)
```

    #> # A tibble: 6 × 2
    #>   value_label    value_code
    #>   <chr>          <chr>
    #> 1 August 2013    201308
    #> 2 August 2019    201908
    #> 3 August 2022    202208
    #> 4 November 2022  202211     # ← newly added
    #> 5 February 2023  202302     # ← newly added
    #> 6 May 2023       202305     # ← newly added

Setting `.add_only_newer_dates = FALSE` would instead add *all* dates
available in the schema that are not already present in the spec (useful
if you also want to fill in historical gaps).

## Step 4 – Re-add labels for the new rows

The newly appended rows already have label and location columns
populated by `update_spec_table_to_latest_data()`, so this step is
usually not needed. If you find any rows with missing labels (e.g. after
manual edits), re-run:

``` r
spec_tbl_updated <- spec_tbl_updated |>
  add_labels_and_locations_to_spec_table()
```

## Step 5 – (Optional) add a grouping for the date field

You can classify the updated dates into meaningful periods before
fetching. For example, group by financial year or policy era:

``` r
spec_tbl_updated <- spec_tbl_updated |>
  mutate(
    value_group = case_when(
      field_label == "Month" &
        str_detect(value_label, "2013|2019") ~ "Pre-pandemic reference",
      field_label == "Month" &
        str_detect(value_label, "2022|2023") ~ "Post-pandemic",
      TRUE ~ NA_character_
    )
  )
```

## Step 6 – Fetch the updated data

``` r
acc_updated <- fetch_data_from_spec_table(spec_tbl_updated)

head(acc_updated)
```

    #>   V_F_ACC   AGE DATE_NAME              WARD_CODE EMP         value
    #>   <chr>     <chr> <chr>                <chr>     <chr>       <dbl>
    #> 1 ACC count 16    August 2013          England   Employed       12
    #> 2 ACC count 16    November 2022        England   Employed       14
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
| 3 | `update_spec_table_to_latest_data()` | Append newer date values from schema |
| 4 | `mutate(value_group = ...)` | *(optional)* group the updated dates |
| 5 | `fetch_data_from_spec_table()` | Fetch data including new dates |
| 6 | `convert_spec_table_to_list()` + `export_json()` | *(optional)* save updated spec |
