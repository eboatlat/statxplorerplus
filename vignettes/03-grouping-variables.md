
# 3. Grouping variables in a spec table

## Overview

Stat-Xplore lets you aggregate individual values into groups using
*recodes*. `statxplorerplus` represents these groupings in the
`value_group` column of a **spec table**: rows sharing the same
`value_group` string are collapsed into a single category when the query
is sent to the API.

This vignette shows how to:

1.  Convert a JSON spec to a spec table.
2.  Add human-readable labels so you can see what each row refers to.
3.  Assign `value_group` labels to create age-band groupings.
4.  Fetch the grouped data.

## Step 1 – Load the package and set your API key

``` r
library(statxplorerplus)
library(dplyr)

load_api_key("path/to/apikey.txt")
```

## Step 2 – Convert the JSON to a spec table

``` r
json_path <- "path/to/acc_ew_by_single_year_of_age_pre19.json"

spec_tbl <- convert_json_to_spec_table(json_path)

spec_tbl
```

    #> # A tibble: 57 × 5
    #>   database_id      measure_id            field_id
    #>   <chr>            <chr>                 <chr>
    #> 1 str:database:ACC str:count:ACC:V_F_ACC str:field:ACC:V_F_ACC:AGE
    #> 2 str:database:ACC str:count:ACC:V_F_ACC str:field:ACC:V_F_ACC:AGE
    #> ...

## Step 3 – Add labels so you can identify the values

``` r
spec_tbl_labelled <- spec_tbl |>
  add_labels_and_locations_to_spec_table()

spec_tbl_labelled |>
  select(field_label, value_label, value_code)
```

    #> # A tibble: 57 × 3
    #>   field_label                    value_label value_code
    #>   <chr>                          <chr>       <chr>
    #> 1 Age of Claimant (Single Years) 16          16
    #> 2 Age of Claimant (Single Years) 17          17
    #> 3 Age of Claimant (Single Years) 18          18
    #> ...

## Step 4 – Assign age-band groupings via `value_group`

Add a `value_group` column to define how individual values are
collapsed. Rows without a `value_group` (i.e. `NA`) are kept as
individual categories. Here we group single years of age into three
broad bands:

``` r
spec_tbl_grouped <- spec_tbl_labelled |>
  mutate(
    value_group = case_when(
      field_label == "Age of Claimant (Single Years)" &
        as.integer(value_code) %in% 16:34 ~ "16-34",
      field_label == "Age of Claimant (Single Years)" &
        as.integer(value_code) %in% 35:54 ~ "35-54",
      field_label == "Age of Claimant (Single Years)" &
        as.integer(value_code) >= 55      ~ "55+",
      TRUE ~ NA_character_
    )
  )

spec_tbl_grouped |>
  filter(field_label == "Age of Claimant (Single Years)") |>
  select(value_label, value_code, value_group)
```

    #> # A tibble: 51 × 3
    #>   value_label value_code value_group
    #>   <chr>       <chr>      <chr>
    #> 1 16          16         16-34
    #> 2 17          17         16-34
    #> ...
    #> 20 35          35         35-54
    #> ...
    #> 40 55          55         55+

## Step 5 – Fetch the grouped data

Pass the spec table (with `value_group` populated) directly to
`fetch_data_from_spec_table()`. The groupings are applied automatically
before the query is sent.

``` r
acc_grouped <- fetch_data_from_spec_table(spec_tbl_grouped)

head(acc_grouped)
```

    #>   V_F_ACC   AGE   DATE_NAME    WARD_CODE EMP        value
    #>   <chr>     <chr> <chr>        <chr>     <chr>      <dbl>
    #> 1 ACC count 16-34 August 2013  England   Employed    4821
    #> 2 ACC count 16-34 August 2013  England   Unemployed  1203
    #> ...

## How grouping works under the hood

When `value_group` is set, `fetch_data_from_spec_table()` calls
`construct_custom_var_mapping_from_spec_table()` to build a named list
that maps group labels to the individual Stat-Xplore value IDs. This
list is forwarded to `extract_results()` so that the API response is
correctly labelled with your custom group names instead of the raw IDs.

## Summary

| Step | Function | Purpose |
|----|----|----|
| 1 | `convert_json_to_spec_table()` | Parse JSON → spec table |
| 2 | `add_labels_and_locations_to_spec_table()` | Add human-readable labels |
| 3 | `mutate(value_group = ...)` | Define age-band groupings |
| 4 | `fetch_data_from_spec_table()` | Fetch grouped data from API |
