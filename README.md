# statxplorerplus

**statxplorerplus** is an R package that makes it easier to download and
work with data from
[Stat-Xplore](https://stat-xplore.dwp.gov.uk) — the DWP's online data
portal covering benefits, claimants, and related statistics.

It builds on the
[`statxplorer`](https://github.com/houseofcommonslibrary/statxplorer)
package developed by the House of Commons Library, extending it with tools
to construct, modify, and reuse queries entirely within R.

## Getting started

You will need a Stat-Xplore API key. You can register for a free account at
<https://stat-xplore.dwp.gov.uk>.

**Install the package:**

```r
# install.packages("remotes")
remotes::install_github("eboatlat/statxplorerplus")
```

**Set your API key:**

```r
library(statxplorerplus)

load_api_key("path/to/apikey.txt")
```

## The specification table (spec table)

The central concept in this package is the **spec table** — a plain R data
frame where each row represents one value selected in a Stat-Xplore query
For example, a simple query selecting one age, one geography, and one month
produces a spec table with three rows — one per selected value:

```
# A tibble: 3 × 7
  database_id        field_id                       value_id                                    database_label             field_label     value_label  value_code
  <chr>              <chr>                          <chr>                                       <chr>                      <chr>           <chr>        <chr>
1 str:database:ACC   str:field:ACC:V_F_ACC:AGE      str:value:ACC:V_F_ACC:AGE:...:16            Attendance Allowance (ACC) Age (Single)    16           16
2 str:database:ACC   str:field:ACC:V_F_ACC:WARD_CODE str:value:ACC:V_F_ACC:WARD_CODE:...:E92000001 Attendance Allowance (ACC) Region/Country  England      E92000001
3 str:database:ACC   str:field:ACC:F_ACC_DATE:DATE  str:value:ACC:F_ACC_DATE:DATE:...:202208    Attendance Allowance (ACC) Month           August 2022  202208
```

If you downloaded data based on this specification table you would get information on the number of people on 'alternative claimant count' how are aged 16 and live in England.

```r
library(statxplorerplus)

load_api_key("path/to/apikey.txt")

data <- fetch_data_from_spec_table(spec_tbl)

data
#> # A tibble: 1 × 6
#>   database_label             measure_label      AGE   WARD_CODE DATE_NAME    value
#>   <chr>                      <chr>              <chr> <chr>     <chr>        <dbl>
#> 1 Attendance Allowance (ACC) ACC claimant count 16    England   August 2022   1042
```

Because it is just a data frame, you can inspect, filter, and modify a
query using standard R tools before downloading any data. This makes it
straightforward to:

- **Subset** the query to only the values you need before fetching — see
  [Guide 2](vignettes/02-subsetting-queries.md)
- **Modify** specific values in an existing query (e.g. swap age or
  geography) — see [Guide 3](vignettes/03-modifying-queries.md)
- **Group** individual values into broader categories (e.g. age bands) by
  adding a `value_group` column — see
  [Guide 4](vignettes/04-grouping-variables.md)
- **Extend** a query to cover newer time periods automatically — see
  [Guide 5](vignettes/05-update-to-latest-data.md)
- **Build** an entirely new query from scratch by browsing the data
  catalogue — see [Guide 6](vignettes/06-build-query-from-scratch.md)

Once you are happy with the spec table, pass it to
`fetch_data_from_spec_table()` to download the data.

## What can I do with this package?

### Download data directly from a JSON file

If you have already exported a query as a JSON file from the Stat-Xplore
website, you can download the data in one line — no spec table needed:

```r
data <- fetch_table(filename = "path/to/my_query.json")
```

See [Guide 1](vignettes/01-fetch-from-json.md) for a full walkthrough.

### Load a query into a spec table and modify it

Convert a JSON file into a spec table, make changes in R, then download:

```r
spec_tbl <- convert_json_to_spec_table("path/to/my_query.json") |>
  add_labels_and_locations_to_spec_table()

# Inspect the query
spec_tbl |> select(field_label, value_label)

# Download
data <- fetch_data_from_spec_table(spec_tbl)
```

### Group values into broader categories

Add a `value_group` column to the spec table to collapse individual values
into custom categories before downloading. For example, grouping single
years of age into bands:

```r
spec_tbl_grouped <- spec_tbl |>
  mutate(
    value_group = case_when(
      field_label == "Age (Single)" &
        as.integer(value_code) %in% 16:34 ~ "16-34",
      field_label == "Age (Single)" &
        as.integer(value_code) %in% 35:54 ~ "35-54",
      field_label == "Age (Single)" &
        as.integer(value_code) >= 55      ~ "55+",
      TRUE ~ NA_character_
    )
  )

data <- fetch_data_from_spec_table(spec_tbl_grouped)
```

See [Guide 4](vignettes/04-grouping-variables.md) for more detail.

### Update a query to include the latest data

Rather than manually editing a query each time new data is published,
`update_spec_table_to_latest_data()` checks the Stat-Xplore schema and
adds any time periods not already in the spec table:

```r
spec_tbl_updated <- spec_tbl |>
  update_spec_table_to_latest_data()

data <- fetch_data_from_spec_table(spec_tbl_updated)
```

See [Guide 5](vignettes/05-update-to-latest-data.md) for more detail.

### Build a query from scratch in R

Browse the available datasets, fields, and values directly in R to build a
spec table without exporting a JSON file from the website first. See
[Guide 6](vignettes/06-build-query-from-scratch.md) for a full walkthrough.

## Guides

| Guide | What it covers |
|---|---|
| [1. Fetch from JSON](vignettes/01-fetch-from-json.md) | Download data using an existing JSON query file |
| [2. Subsetting queries](vignettes/02-subsetting-queries.md) | Filter a spec table to a subset of values before fetching |
| [3. Modifying queries](vignettes/03-modifying-queries.md) | Swap specific values in a query (e.g. different age or geography) |
| [4. Grouping variables](vignettes/04-grouping-variables.md) | Collapse values into broader groups using a spec table |
| [5. Update to latest data](vignettes/05-update-to-latest-data.md) | Extend a spec table to cover the most recent time periods |
| [6. Build a query from scratch](vignettes/06-build-query-from-scratch.md) | Browse the data catalogue and build a spec table in R |
