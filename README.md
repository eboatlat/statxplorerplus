# statxplorerplus

**statxplorerplus** is an R package for working with the
[DWP Stat-Xplore API](https://stat-xplore.dwp.gov.uk). It provides tools
to query the API, convert JSON spec files to tidy tables and back, resolve
human-readable labels to Stat-Xplore IDs, and keep existing queries up to
date as new data is released.

## Background

This package builds on the
[`statxplorer`](https://github.com/houseofcommonslibrary/statxplorer)
package developed by the House of Commons Library, which provides the
foundational R interface to the Stat-Xplore REST API. `statxplorerplus`
extends that work with a higher-level workflow centred on a tidy **spec
table** format, adding:

- Conversion between Stat-Xplore JSON spec files and tidy tibbles
- Schema-driven label resolution and fuzzy matching
- Automatic detection and appending of newer date values
- Support for grouped recodes (custom aggregate variables)
- Utilities for navigating the Stat-Xplore schema interactively

## Installation

```r
# install.packages("remotes")
remotes::install_github("eboatlat/statxplorerplus")
```

## Getting started

You will need a Stat-Xplore API key. Register for free at
<https://stat-xplore.dwp.gov.uk>.

```r
library(statxplorerplus)

# Load your key from a file (recommended)
load_api_key("path/to/apikey.txt")

# Or set it directly for the session
set_api_key("your-api-key")
```

## Core workflows

### 1. Fetch data directly from a JSON spec

The quickest route if you already have a Stat-Xplore JSON export:

```r
data <- fetch_table(filename = "path/to/query.json")
```

### 2. Convert a JSON spec to a spec table

The **spec table** is the central data structure in this package — a tidy
tibble with one row per selected value. Converting to a spec table lets you
inspect, modify, or extend the query in R before fetching:

```r
spec_tbl <- convert_json_to_spec_table("path/to/query.json") |>
  add_labels_and_locations_to_spec_table()

data <- fetch_data_from_spec_table(spec_tbl)
```

### 3. Group variables before fetching

Add a `value_group` column to collapse individual values into custom
categories (e.g. age bands):

```r
spec_tbl_grouped <- spec_tbl |>
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

data <- fetch_data_from_spec_table(spec_tbl_grouped)
```

### 4. Update a spec to the latest available data

Automatically append date values that have been published since the spec
was created:

```r
spec_tbl_updated <- spec_tbl |>
  update_spec_table_to_latest_data()

data <- fetch_data_from_spec_table(spec_tbl_updated)
```

### 5. Build a query from scratch

Browse the schema interactively, assemble a labels table, and convert it
to a spec table without needing to export a JSON from the Stat-Xplore UI:

```r
databases  <- list_databases()
fields     <- get_target_type_info_below(db_location, "FIELD")
values     <- get_next_level_info(field_location)

spec_tbl <- my_labels_table |>
  convert_labels_table_to_spec_table()

export_json(convert_spec_table_to_list(spec_tbl), "path/to/output.json")
```

## Vignettes

Step-by-step guides are available in the
[`vignettes/`](vignettes/) folder:

| Vignette | Description |
|---|---|
| [01 – Fetch from JSON](vignettes/01-fetch-from-json.md) | Fetch data directly from an existing JSON spec |
| [02 – Grouping variables](vignettes/02-grouping-variables.md) | Collapse values into custom groups via the spec table |
| [03 – Update to latest data](vignettes/03-update-to-latest-data.md) | Append newer date values automatically |
| [04 – Build a query from scratch](vignettes/04-build-query-from-scratch.md) | Navigate the schema and build a query without a JSON file |

## Key functions

| Function | Purpose |
|---|---|
| `load_api_key()` / `set_api_key()` | Set your Stat-Xplore API key |
| `fetch_table()` | Query the API from a JSON file or string |
| `fetch_data_from_spec_table()` | Query the API from a spec table |
| `convert_json_to_spec_table()` | Parse a JSON spec into a tidy tibble |
| `convert_spec_table_to_list()` | Convert a spec table back to a JSON list |
| `add_labels_and_locations_to_spec_table()` | Enrich a spec table with human-readable labels |
| `update_spec_table_to_latest_data()` | Append newer dates from the schema |
| `list_databases()` | List all available Stat-Xplore databases |
| `get_target_type_info_below()` | Find all fields or measures under a database |
| `get_next_level_info()` | Step one level down the schema tree |
| `convert_labels_table_to_spec_table()` | Resolve human-readable labels to IDs |
| `export_json()` | Write a spec list to a JSON file |
