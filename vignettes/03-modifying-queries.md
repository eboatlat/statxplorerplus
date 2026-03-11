
# 3. Modifying an existing query

## Overview

Once a query is loaded into a spec table, you can change any of its values
using standard `dplyr` operations — no need to edit the JSON file directly.

This vignette starts with a query that downloads Attendance Allowance (ACC)
claimant counts for **age 16 in England in August 2022** and modifies it to
instead download the same data for **age 17 in Wales**.

Rather than hardcoding the Stat-Xplore value IDs for "Wales" and "17", the
vignette shows how to look them up from the spec table itself using
`get_schema_info()`.

## Step 1 – Load the package and set your API key

``` r
library(statxplorerplus)
library(dplyr)

load_api_key("path/to/apikey.txt")
```

## Step 2 – Load the original query

Convert the JSON to a spec table and add labels and schema locations:

``` r
json_path <- system.file("extdata", "acc_england_age_16_aug22.json",
                         package = "statxplorerplus")

spec_tbl <- convert_json_to_spec_table(json_path) |>
  add_labels_and_locations_to_spec_table()
```

Inspect the spec table — each row is one selected value:

``` r
spec_tbl |>
  select(field_label, value_label, value_code)
```

    #> # A tibble: 3 × 3
    #>   field_label    value_label value_code
    #>   <chr>          <chr>       <chr>
    #> 1 Age (Single)   16          16
    #> 2 Region/Country England     E92000001
    #> 3 Month          August 2022 202208

## Step 3 – Browse available values to find the IDs you need

The spec table includes a `valueset_location` column — a schema URL pointing
to all possible values for each field. Use `get_schema_info()` on these URLs
to see what is available.

**Find the Wales value ID:**

``` r
geo_valueset_url <- spec_tbl |>
  filter(field_label == "Region/Country") |>
  pull(valueset_location)

get_schema_info(geo_valueset_url) |>
  select(child_label, child_id)
```

    #> # A tibble: 4 × 2
    #>   child_label      child_id
    #>   <chr>            <chr>
    #> 1 England          str:value:ACC:V_F_ACC:WARD_CODE:V_C_MASTERGEOG11_COUNTRY_TO_UK:E92000001
    #> 2 Wales            str:value:ACC:V_F_ACC:WARD_CODE:V_C_MASTERGEOG11_COUNTRY_TO_UK:W92000004
    #> 3 Scotland         str:value:ACC:V_F_ACC:WARD_CODE:V_C_MASTERGEOG11_COUNTRY_TO_UK:S92000003
    #> 4 Northern Ireland str:value:ACC:V_F_ACC:WARD_CODE:V_C_MASTERGEOG11_COUNTRY_TO_UK:N92000002

**Find the age 17 value ID:**

``` r
age_valueset_url <- spec_tbl |>
  filter(field_label == "Age (Single)") |>
  pull(valueset_location)

get_schema_info(age_valueset_url) |>
  filter(child_label %in% c("16", "17")) |>
  select(child_label, child_id)
```

    #> # A tibble: 2 × 2
    #>   child_label child_id
    #>   <chr>       <chr>
    #> 1 16          str:value:ACC:V_F_ACC:AGE:C_ACC_SINGLE_AGE:16
    #> 2 17          str:value:ACC:V_F_ACC:AGE:C_ACC_SINGLE_AGE:17

Now extract the IDs into variables:

``` r
wales_id <- get_schema_info(geo_valueset_url) |>
  filter(child_label == "Wales") |>
  pull(child_id)

age17_id <- get_schema_info(age_valueset_url) |>
  filter(child_label == "17") |>
  pull(child_id)
```

## Step 4 – Modify the query

Replace the age and geography values in the spec table using `mutate()` and
`case_when()`. Note that `value_code` is updated last so the earlier
conditions can still match on the original value:

``` r
spec_tbl_modified <- spec_tbl |>
  mutate(
    value_id = case_when(
      value_code == "16"        ~ age17_id,
      value_code == "E92000001" ~ wales_id,
      TRUE                      ~ value_id
    ),
    value_label = case_when(
      value_code == "16"        ~ "17",
      value_code == "E92000001" ~ "Wales",
      TRUE                      ~ value_label
    ),
    value_code = case_when(
      value_code == "16"        ~ "17",
      value_code == "E92000001" ~ "W92000004",
      TRUE                      ~ value_code
    )
  )

spec_tbl_modified |>
  select(field_label, value_label, value_code)
```

    #> # A tibble: 3 × 3
    #>   field_label    value_label value_code
    #>   <chr>          <chr>       <chr>
    #> 1 Age (Single)   17          17
    #> 2 Region/Country Wales       W92000004
    #> 3 Month          August 2022 202208

## Step 5 – Fetch the modified data

``` r
acc_17_wales <- fetch_data_from_spec_table(spec_tbl_modified)

acc_17_wales
```

    #> # A tibble: 1 × 5
    #>   database_label             measure_label      AGE   WARD_CODE DATE_NAME    value
    #>   <chr>                      <chr>              <chr> <chr>     <chr>        <dbl>
    #> 1 Attendance Allowance (ACC) ACC claimant count 17    Wales     August 2022    287

## Step 6 – (Optional) export the modified query as a new JSON

Save the modified spec table as a JSON file so it can be reused later:

``` r
modified_list <- convert_spec_table_to_list(spec_tbl_modified)

export_json(
  .json        = modified_list,
  .output_path = "path/to/acc_wales_age_17_aug22.json"
)
```

## Summary

| Step | Code | Purpose |
|----|----|----|
| 1 | `convert_json_to_spec_table()` | Parse JSON → spec table |
| 2 | `add_labels_and_locations_to_spec_table()` | Add labels and schema locations |
| 3 | `get_schema_info()` on `valueset_location` | Browse available values to find IDs |
| 4 | `mutate()` + `case_when()` | Replace the age and geography values |
| 5 | `fetch_data_from_spec_table()` | Fetch the modified query |
| 6 | `convert_spec_table_to_list()` + `export_json()` | Save as a new JSON |
