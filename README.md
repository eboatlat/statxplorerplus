# statxplorerplus

**statxplorerplus** is an R package that makes it easier to download and
work with data from
[Stat-Xplore](https://stat-xplore.dwp.gov.uk) — the DWP's online data
portal covering benefits, claimants, and related statistics.

It builds on the
[`statxplorer`](https://github.com/houseofcommonslibrary/statxplorer)
package developed by the House of Commons Library, extending it with tools
to construct, modify, and reuse queries entirely within R.

## What can I do with this package?

### Download data from Stat-Xplore

If you have exported a query as a JSON file from the Stat-Xplore website,
you can download the data in one line:

```r
data <- fetch_table(filename = "path/to/my_query.json")
```

### Build a query without leaving R

You can browse the available datasets, fields, and values directly in R and
put together a query without needing to use the Stat-Xplore website at all:

```r
# See what datasets are available
databases <- list_databases()

# See what fields are available in a dataset
fields <- get_target_type_info_below(db_location, "FIELD")

# Build your query and download the data
data <- fetch_data_from_spec_table(my_spec_table)
```

### Modify an existing query

Load an existing JSON query into R as a table, make changes, and download
the updated data — without manually editing the JSON file:

```r
spec_tbl <- convert_json_to_spec_table("path/to/my_query.json") |>
  add_labels_and_locations_to_spec_table()
```

### Group observations together

Collapse individual values into broader categories. For example, group
single years of age into age bands:

```r
spec_tbl_grouped <- spec_tbl |>
  mutate(
    value_group = case_when(
      field_label == "Age" & as.integer(value_code) %in% 16:34 ~ "16-34",
      field_label == "Age" & as.integer(value_code) %in% 35:54 ~ "35-54",
      field_label == "Age" & as.integer(value_code) >= 55      ~ "55+",
      TRUE ~ NA_character_
    )
  )

data <- fetch_data_from_spec_table(spec_tbl_grouped)
```

### Update a query to the latest available data

Stat-Xplore data is updated regularly. Rather than manually adding new time
periods to your query each time, this package can detect what is new and add
it automatically:

```r
spec_tbl_updated <- spec_tbl |>
  update_spec_table_to_latest_data()

data <- fetch_data_from_spec_table(spec_tbl_updated)
```

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

## Guides

Step-by-step guides are available in the
[`vignettes/`](vignettes/) folder:

| Guide | What it covers |
|---|---|
| [1. Fetch from JSON](vignettes/01-fetch-from-json.md) | Download data using an existing JSON query file |
| [2. Grouping variables](vignettes/02-grouping-variables.md) | Combine individual values into broader groups |
| [3. Update to latest data](vignettes/03-update-to-latest-data.md) | Add the most recent time periods to an existing query |
| [4. Build a query from scratch](vignettes/04-build-query-from-scratch.md) | Browse the data catalogue and build a query in R |
