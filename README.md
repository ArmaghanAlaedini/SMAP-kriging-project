# 🛰️ SMAP Kriging Project (Iowa Township-level Soil Moisture)

This repository contains an R-based workflow to convert NASA SMAP soil moisture HDF5 files into Iowa township-level soil moisture products, including static maps and interactive Leaflet/Shiny outputs.

> **Note:** SMAP data files are **not included** in this repository.  
> You can **manually download SMAP data** using NASA's Earthdata or NSIDC websites.

---
## ⬇️ Data acquisition workflow

1. Create an Earthdata Login.
2. Use Earthdata Search to find the SMAP soil moisture product you want to analyze. NSIDC website also directs you to the Earthdata platform.
3. Download the SMAP HDF5 granule(s).
4. Place the downloaded file(s) into the folder specified by `cfg$data_dir` in `src/00_config.R`. These folders are also automatically created once you run `src/00_config.R`.
5. Update in `src/00_config.R`:
   - `cfg$data_file` (downloaded file name)

---

## 📂 Repository structure

```text
src/
  00_config.R
  01_utils_theme.R
  02_smap_hdf5.R
  03_detrend.R
  04_kriging.R
  05_plots.R
  06_interactive_plot.R
README.md
.gitignore
```
**How to run the pipeline:** Run scripts in the following order from the repository root.

```
bash
Copy code
Rscript src/02_smap_hdf5.R
Rscript src/03_detrend.R
Rscript src/04_kriging.R
Rscript src/05_plots.R
Rscript src/06_interactive_plot.R
```
---

## 🧩 Script description

`src/00_config.R` — Configuration

Defines project settings used everywhere: input file paths, date tag, CRS settings, output directories, plot limits, and kriging parameters.

`src/01_utils_theme.R` — Plot theme + saving helpers

Reusable functions for consistent plotting and saving (e.g., SMAP_theme(), save PNG/PDF maps, save interactive HTML widgets).

`src/02_smap_hdf5.R` — Read SMAP HDF5 and prepare observations

Reads the downloaded SMAP HDF5 file and extracts soil moisture data (AM/PM), coordinates, and needed variables. Creates analysis-ready outputs (CSV/RDS).

`src/03_detrend.R` — Detrend soil moisture for kriging

Fits and removes a spatial trend so kriging is applied to (approximately) stationary residuals. Saves detrended values and the trend model to add back after kriging.

`src/04_kriging.R` — Variogram + township prediction + uncertainty

Builds a semivariogram model and performs kriging to produce township-level predicted soil moisture (trend added back) and kriging standard deviation (uncertainty).

`src/05_plots.R` — Static maps (PNG/PDF)

Creates publication-ready static maps for observed data, predicted soil moisture, and uncertainty using the project theme and limits.

`src/06_interactive_plot.R` — Interactive Leaflet HTML + Shiny app

Creates interactive township maps using Leaflet (basemap tiles, hover labels, legend) and saves HTML maps; includes a Shiny app for pass selection (AM/PM).

---

## 🗺️ Outputs

Typical outputs include:

- *.rds objects (observations, detrended fields, predictions)

- ggplot static maps (.png / .pdf)

- interactive Leaflet map  (.html)

---

## 📩 Contact

Maintainer: Armaghan Alaedini

Email: alaedini.iastate.edu