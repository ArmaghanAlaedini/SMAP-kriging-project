# 🛰️ SMAP Kriging Project (Iowa Township-level Soil Moisture)

An automated daily pipeline that converts NASA SMAP soil moisture HDF5 granules
(SPL3SMP_E) into Iowa township-level soil moisture estimates with kriging
uncertainty, using area-to-area kriging.

The daily deliverable is one tidy CSV per date, intended for ingest and display
by the Iowa Environmental Mesonet. Static maps and interactive Leaflet maps are
produced as byproducts for inspection.

> **Note:** SMAP granules and the township shapefile are **not included** in this
> repository. Granules are downloaded automatically; the shapefile must be placed
> manually (see below).

---

## ⚡ Quick start

```bash
conda env create -f environment.yml
conda activate smap-kriging-r
Rscript install_extra.R

# one date, end to end YYYY-MM-DD
python fetch_smap.py 2026-09-07
Rscript run_day.R 2026-09-07
```

Result: `output/iem/smap_townships_20260907.csv`

---

## 🔑 Prerequisites

**1. Earthdata Login**

Register at <https://urs.earthdata.nasa.gov>, then create `~/.netrc`:

```
machine urs.earthdata.nasa.gov login YOUR_USERNAME password YOUR_PASSWORD
```

```bash
chmod 600 ~/.netrc
```

If your account has multi-factor authentication enabled, password login will not
work. Generate a token in your Earthdata profile and save it to `~/.edl_token`
(also `chmod 600`), which `fetch_smap.py` uses in preference to `.netrc`.

**2. Township shapefile**

Place the Iowa civil townships shapefile from the Iowa State GIS Facility in
`data/civil_townships/`. All sidecar files are required, not just the `.shp`:

```text
data/civil_townships/
  civil_townships_a_ia.shp
  civil_townships_a_ia.shx
  civil_townships_a_ia.dbf
  civil_townships_a_ia.prj
```

The file is in NAD83 UTM Zone 15N and is reprojected by the pipeline. Only
records with `TYPE == 0` are used, which excludes incorporated cities, leaving
1595 townships.

---

## 🔁 Daily operation

`run_daily.sh` is the cron entry point. It walks back a rolling window of dates,
downloads any granule not already on disk, and processes any date not yet done.

```bash
./run_daily.sh        # last 5 days
./run_daily.sh 30     # backfill a month
```

Crontab:

```text
15 7 * * * /path/to/IA-smap-kriging/run_daily.sh >> /path/to/smap.log 2>&1
```

The rolling window is not optional. SPL3SMP_E granules publish with about a day
of latency, are occasionally reprocessed, and some dates are simply missing
(2026-09-03, for example, has no granule). Processing only yesterday would leave
permanent gaps in the record.

Both `fetch_smap.py` and `run_day.R` are idempotent. Re-running a finished date
does nothing unless you set `SMAP_FORCE=1`.

---

## 📂 Repository structure

```text
fetch_smap.py            download one date from Earthdata (earthaccess)
run_day.R                run the full pipeline for one date
run_daily.sh             cron entry point, rolling window
src/
  00_config.R            settings, date resolution, output paths
  01_utils_theme.R       ggplot theme and save helpers
  02_smap_hdf5.R         HDF5 to per-pass compressed CSV
  03_detrend.R           Iowa subset, EASE cells, trend removal
  04_kriging.R           variogram deconvolution and area-to-area kriging
  05_plots.R             static PNG and PDF maps
  06_interactive_plot.R  Leaflet HTML (pass + layer switcher) and Shiny app
  07_export_iem.R        flat township CSV for downstream ingest
environment.yml
install_extra.R
README.md
```

---

## 📅 The date is an argument, not an edit

`src/00_config.R` resolves the date in this order:

1. the `SMAP_DATE` environment variable (`YYYY-MM-DD`), which `run_day.R` sets
2. the newest granule found in `data/raw_data/`
3. yesterday

It then locates the granule on disk by matching the date portion of the
filename. Nothing is hardcoded and no file is edited between runs.

The filename embeds a release string, for example
`SMAP_L3_SM_P_E_20260907_R19240_001.h5`, which cannot be derived from the date.
That is why the download queries NASA's Common Metadata Repository through
`earthaccess` rather than building a URL.

To run one script by hand:

```bash
SMAP_DATE=2026-09-07 Rscript src/03_detrend.R
```

Scripts under `src/` expect `src/` as the working directory, since they
`source("00_config.R")` by relative path. `run_day.R` handles this for you.

---

## 🧩 Script description

`src/00_config.R` — Configuration

Project settings used everywhere: date resolution, granule lookup, CRS settings,
output directories, plot limits, and kriging parameters.

`src/01_utils_theme.R` — Plot theme + saving helpers

Reusable functions for consistent plotting and saving (`SMAP_theme()`, PNG/PDF
map saving, HTML widget saving).

`src/02_smap_hdf5.R` — Read SMAP HDF5 and prepare observations

Reads the granule and extracts soil moisture (AM/PM) and coordinates. Masks fill
values and values outside the valid range declared in the dataset attributes.
Writes one compressed CSV per pass.

`src/03_detrend.R` — Detrend soil moisture for kriging

Subsets to an Iowa bounding box, rebuilds each 9 km EASE-Grid 2.0 retrieval as a
square polygon, then fits and removes a spatial trend by backward selection over
a quadratic surface, so kriging is applied to approximately stationary residuals.

`src/04_kriging.R` — Variogram + township prediction + uncertainty

Deconvolves the areal semivariogram to a point-support model and performs
area-to-area kriging onto township polygons, producing estimated soil moisture
(trend added back) and kriging standard deviation. A pass with fewer than
`cfg$min_cells` valid retrievals is skipped, since a variogram cannot be fitted
from a handful of points.

`src/05_plots.R` — Static maps (PNG/PDF)

Publication-ready static maps for observed data, estimated soil moisture, and
uncertainty using the project theme and limits.

`src/06_interactive_plot.R` — Interactive Leaflet HTML + Shiny app

One Leaflet HTML per date with a layers control offering up to four choices:
observed SMAP pixels clipped to Iowa, and estimated townships, each for the AM
and PM passes. The observed layer reads `cells_ease_detrended.rds`, so a pass
whose kriging was skipped still shows its actual retrievals. The Shiny app
offers the same choices as pass and data dropdowns, plus a GeoPackage download.
Runs under `Rscript`; the `shinyApp()` call is guarded by `if (interactive())`.

`src/07_export_iem.R` — Flat CSV for publication

Flattens the township estimates into one tidy CSV per date. This is the handoff
point to the Iowa Environmental Mesonet, and the column names here are the data
contract, so change them deliberately.

---

## 🗺️ Outputs

**Deliverable:** `output/iem/smap_townships_YYYYMMDD.csv`, one row per township
per available pass.

| column | meaning |
| --- | --- |
| `valid_date` | observation date, `YYYY-MM-DD` |
| `pass` | `AM` or `PM` |
| `politwp_id` | township identifier from the shapefile |
| `county` | county name |
| `township` | township name |
| `sm_est` | estimated volumetric soil moisture, m³/m³ |
| `sm_krige_sd` | kriging standard deviation, m³/m³ |
| `area_km2` | township area |

Written to a temporary name and renamed on completion, so a process polling the
directory never reads a partial file. Expect 1595 rows per pass.

**Byproducts:**

- `output/rds/YYYYMMDD/{AM,PM}/` — intermediate objects (observations, detrended
  fields, predictions)
- `output/maps/YYYYMMDD/{AM,PM}/` — ggplot static maps (`.png` / `.pdf`)
- `output/interactive maps/YYYYMMDD/` — one Leaflet map per date (`.html`)

Only a pass that crosses Iowa on a given date produces output. A missing pass is
normal and is skipped without error.

---

## 📦 Packages

```bash
conda env create -f environment.yml
conda activate smap-kriging-r
Rscript install_extra.R
```

The conda environment provides R, `sf`, `rhdf5`, `leaflet`, and a Python
interpreter with `earthaccess`. `install_extra.R` adds `atakrig` from CRAN.

---

## 📩 Contact

Maintainer: Armaghan Alaedini

Email: <alaedini@iastate.edu>