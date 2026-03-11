
# 6. Building a query from scratch using the schema

## Overview

Sometimes you want to build a Stat-Xplore query from scratch rather than
starting from an existing JSON file. `statxplorerplus` provides a set of
schema-navigation functions that let you browse the available databases,
fields, and values interactively, then turn what you find into a spec
table and a JSON file you can reuse.

This vignette shows how to:

1.  List all available databases.
2.  Explore measures and fields within a database.
3.  Inspect the values available for a field.
4.  Assemble a labels table and convert it to a spec table.
5.  Export the spec table as a JSON file.
6.  Fetch the data.

## Step 1 – Load the package and set your API key

``` r
library(statxplorerplus)
library(dplyr)
library(tibble)

load_api_key("path/to/apikey.txt")
```

## Step 2 – List available databases

``` r
databases <- list_databases()

databases
```

    #> # A tibble: 30 × 3
    #>   id                   label                        location
    #>   <chr>                <chr>                        <chr>
    #> 1 str:database:ACC     Attendance Allowance (ACC)   https://.../str:database:ACC
    #> 2 str:database:CESA    ...
    #> ...

Pick the database you want to work with and save its `location` — this
URL is the entry point for further schema navigation.

``` r
acc_location <- databases |>
  filter(label == "Attendance Allowance (ACC)") |>
  pull(location)
```

## Step 3 – Find the measures and fields

`get_target_type_info_below()` traverses the schema tree from a starting
URL and collects all records matching the requested types. Use it to
list all measures and fields in one call:

``` r
measures <- get_target_type_info_below(acc_location, "MEASURE")
fields   <- get_target_type_info_below(acc_location, "FIELD")

measures
```

    #> # A tibble: 1 × 4
    #>   id                    label           type    location
    #>   <chr>                 <chr>           <chr>   <chr>
    #> 1 str:count:ACC:V_F_ACC ACC claimant... MEASURE https://.../str:count:ACC:V_F_ACC

``` r
fields |> select(id, label, location)
```

    #> # A tibble: 8 × 3
    #>   id                                    label                          location
    #>   <chr>                                 <chr>                          <chr>
    #> 1 str:field:ACC:V_F_ACC:AGE             Age of Claimant (Single Years) https://...
    #> 2 str:field:ACC:V_F_ACC:EMP             Employment Indicator           https://...
    #> 3 str:field:ACC:V_F_ACC:WARD_CODE       Region/Country                 https://...
    #> 4 str:field:ACC:F_ACC_DATE_new:DATE_NAME Month                         https://...
    #> ...

## Step 4 – Inspect the values for a field

Use `get_next_level_info()` to step one level down from a field and see
its valuesets, then step down again to see the individual values.

``` r
age_location <- fields |>
  filter(label == "Age of Claimant (Single Years)") |>
  pull(location)

# One level down: valuesets
age_valuesets <- get_next_level_info(age_location)

age_valuesets |> select(id, label, location)
```

    #> # A tibble: 1 × 3
    #>   id                                        label          location
    #>   <chr>                                     <chr>          <chr>
    #> 1 str:valueset:ACC:V_F_ACC:AGE:C_ACC_SINGLE Single years   https://...

``` r
# Two levels down: individual values
age_values <- get_next_level_info(age_valuesets$location[[1]])

age_values |> select(id, label) |> head(10)
```

    #> # A tibble: 10 × 2
    #>   id                                              label
    #>   <chr>                                           <chr>
    #> 1 str:value:ACC:V_F_ACC:AGE:C_ACC_SINGLE_AGE:16  16
    #> 2 str:value:ACC:V_F_ACC:AGE:C_ACC_SINGLE_AGE:17  17
    #> 3 str:value:ACC:V_F_ACC:AGE:C_ACC_SINGLE_AGE:18  18
    #> ...

Repeat for any other fields you want to include in your query.

## Step 5 – Assemble a labels table

Once you know which fields and values you want, assemble a tibble with
one row per value. The columns must be named `database_label`,
`measure_label`, `field_label`, `valueset_label`, and either
`value_label` or `value_code`.

``` r
my_query <- tribble(
  ~database_label,             ~measure_label,    ~field_label,
  ~valueset_label,                          ~value_label,
  # Age field – three individual years
  "Attendance Allowance (ACC)", "ACC claimant count",
  "Age of Claimant (Single Years)", "Single years", "16",
  "Attendance Allowance (ACC)", "ACC claimant count",
  "Age of Claimant (Single Years)", "Single years", "17",
  "Attendance Allowance (ACC)", "ACC claimant count",
  "Age of Claimant (Single Years)", "Single years", "18",
  # Geography field – England only
  "Attendance Allowance (ACC)", "ACC claimant count",
  "Region/Country", "Countries", "England",
  # Date field – two months
  "Attendance Allowance (ACC)", "ACC claimant count",
  "Month", "Month", "August 2022",
  "Attendance Allowance (ACC)", "ACC claimant count",
  "Month", "Month", "August 2023"
)
```

## Step 6 – Convert to a spec table

`convert_labels_table_to_spec_table()` uses fuzzy matching to look up
each label in the schema and return the corresponding Stat-Xplore IDs.
It will warn you if any label matches only approximately, and error if
it cannot find a match.

``` r
spec_tbl <- convert_labels_table_to_spec_table(my_query)

spec_tbl |> select(field_id, value_id, value_label)
```

    #> # A tibble: 6 × 3
    #>   field_id                              value_id                               value_label
    #>   <chr>                                 <chr>                                  <chr>
    #> 1 str:field:ACC:V_F_ACC:AGE             str:value:...:C_ACC_SINGLE_AGE:16     16
    #> 2 str:field:ACC:V_F_ACC:AGE             str:value:...:C_ACC_SINGLE_AGE:17     17
    #> 3 str:field:ACC:V_F_ACC:AGE             str:value:...:C_ACC_SINGLE_AGE:18     18
    #> 4 str:field:ACC:V_F_ACC:WARD_CODE       str:value:...:WARD_CODE:...:England   England
    #> 5 str:field:ACC:F_ACC_DATE_new:DATE_NAME str:value:...:DATE_NAME:...:202208   August 2022
    #> 6 str:field:ACC:F_ACC_DATE_new:DATE_NAME str:value:...:DATE_NAME:...:202308   August 2023

## Step 7 – Export as JSON

Convert the spec table to a list and write it to a JSON file that can be
reused later (e.g. with `fetch_table(filename = ...)` or shared with
colleagues).

``` r
json_list <- convert_spec_table_to_list(spec_tbl)

export_json(
  .json        = json_list,
  .output_path = "path/to/my_new_query.json"
)
```

## Step 8 – Fetch the data

Fetch directly from the spec table without the round-trip through JSON:

``` r
my_data <- fetch_data_from_spec_table(spec_tbl)

head(my_data)
```

    #>   V_F_ACC   AGE DATE_NAME    WARD_CODE value
    #>   <chr>     <chr> <chr>      <chr>     <dbl>
    #> 1 ACC count 16   August 2022 England    1042
    #> 2 ACC count 16   August 2023 England    1089
    #> ...

## Summary

| Step | Function | Purpose |
|----|----|----|
| 1 | `list_databases()` | Browse all available databases |
| 2 | `get_target_type_info_below()` | List all measures and fields |
| 3 | `get_next_level_info()` | Inspect valuesets and values |
| 4 | `tribble()` / `tibble()` | Assemble a labels table |
| 5 | `convert_labels_table_to_spec_table()` | Resolve labels to IDs |
| 6 | `convert_spec_table_to_list()` + `export_json()` | Save as JSON |
| 7 | `fetch_data_from_spec_table()` | Fetch data from API |
