# 00_config.R
# Project settings + folder structure
#
# The processing date comes from the SMAP_DATE environment variable
# (format YYYY-MM-DD). If it is not set, the newest granule on disk is used.
# The granule filename is discovered on disk rather than hardcoded, because
# the release string in the filename (e.g. R19240) cannot be derived from the date.

library(here)

raw_dir <- here("data", "raw_data")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# ---- DATE (must be resolved before cfg, since paths depend on it) ----
# Priority:
#   1. the SMAP_DATE environment variable, if set (this is what run_day.R uses)
#   2. otherwise, the newest granule sitting in data/raw_data
#   3. otherwise, yesterday
smap_date_chr <- Sys.getenv("SMAP_DATE", unset = "")

if (!nzchar(smap_date_chr)) {
  all_h5 <- list.files(raw_dir, pattern = "^SMAP_L3_SM_P_E_[0-9]{8}_.*\\.h5$")
  if (length(all_h5) > 0) {
    tags <- sub("^SMAP_L3_SM_P_E_([0-9]{8})_.*$", "\\1", all_h5)
    smap_date_chr <- format(as.Date(max(tags), format = "%Y%m%d"), "%Y-%m-%d")
    message("00_config | no SMAP_DATE set, using newest granule on disk: ", smap_date_chr)
  } else {
    smap_date_chr <- format(Sys.Date() - 1, "%Y-%m-%d")
    message("00_config | no SMAP_DATE set and no granules on disk, defaulting to ", smap_date_chr)
  }
}

smap_date <- as.Date(smap_date_chr, format = "%Y-%m-%d")
if (is.na(smap_date)) stop("SMAP_DATE is not a valid YYYY-MM-DD date: ", smap_date_chr)

date_tag <- format(smap_date, "%Y%m%d")

# ---- LOCATE THE GRANULE FOR THIS DATE ----

cand_h5 <- list.files(
  raw_dir,
  pattern = paste0("^SMAP_L3_SM_P_E_", date_tag, "_.*\\.h5$"),
  full.names = FALSE
)

# If the granule was reprocessed there may be several; take the last one
# alphabetically, which is the highest release string.
data_file <- if (length(cand_h5) > 0) sort(cand_h5, decreasing = TRUE)[1] else NA_character_

cfg <- list(

  # ---- OUTPUT ROOTS ----
  out_root = here("output"),
  out_maps = here("output", "maps"),
  out_int_maps = here("output", "interactive maps"),
  out_rds  = here("output", "rds"),
  out_iem  = here("output", "iem"),
  min_cells = 200,

  # ---- INPUTS ----
  data_dir      = here("data", "raw_data"),
  smap_dir      = here("data", "SMAP_csv"),
  townships_dir = here("data", "civil_townships"),

  data_file     = data_file,
  townships_shp = here("data", "civil_townships", "civil_townships_a_ia.shp"),

  # ---- CRS + GRID SIZE ----
  crs_wgs84 = 4326,
  crs_ease  = 6933,
  smap_cellsize = 9024.31,

  # ---- DISCRETIZATION ----
  disc_obs = 3000,
  disc_twn = 3000,

  # ---- PLOT LIMITS ----
  lims_sm_global = c(0.01, 0.51),

  # ---- VARIOGRAM / DECONV CONFIG ----
  vgm_model = "Exp",
  ngroup = 12,
  rd = 0.4,
  maxIter = 1000,
  maxSampleNum = 1000)

cfg$smap_date <- smap_date
cfg$date_tag  <- date_tag

# TRUE when running unattended (cron). Used to turn off plot devices and
# progress bars, which either fail or spam the log on a headless machine.
cfg$batch <- !interactive()

# Passes to consider
cfg$passes <- c("AM", "PM")

# SMAP CSV inputs by pass both .gz and .csv
cand_gz  <- setNames(file.path(cfg$smap_dir, sprintf("sm_%s_%s.csv.gz", cfg$date_tag, cfg$passes)), cfg$passes)
cand_csv <- setNames(file.path(cfg$smap_dir, sprintf("sm_%s_%s.csv",    cfg$date_tag, cfg$passes)), cfg$passes)

cfg$smap_csv_pass <- setNames(vector("list", length(cfg$passes)), cfg$passes)

for (p in cfg$passes) {
  if (file.exists(cand_gz[[p]])) {
    cfg$smap_csv_pass[[p]] <- cand_gz[[p]]
  } else if (file.exists(cand_csv[[p]])) {
    cfg$smap_csv_pass[[p]] <- cand_csv[[p]]
  } else {
    cfg$smap_csv_pass[[p]] <- NA_character_
  }
}

cfg$passes_available <- names(cfg$smap_csv_pass)[!is.na(unlist(cfg$smap_csv_pass))]


# Output folders by date + pass
cfg$out_maps_date <- file.path(cfg$out_maps, cfg$date_tag)
cfg$out_inter_maps_date <- file.path(cfg$out_int_maps, cfg$date_tag)
cfg$out_rds_date  <- file.path(cfg$out_rds,  cfg$date_tag)

cfg$out_maps_pass <- setNames(file.path(cfg$out_maps_date, cfg$passes), cfg$passes)
cfg$out_inter_maps_pass <- setNames(file.path(cfg$out_inter_maps_date, cfg$passes), cfg$passes)
cfg$out_rds_pass  <- setNames(file.path(cfg$out_rds_date,  cfg$passes), cfg$passes)

# Create base dirs
dir.create(cfg$out_root, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$out_maps, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$out_int_maps, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$out_rds,  recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$out_iem,  recursive = TRUE, showWarnings = FALSE)

# Create dated dirs
dir.create(cfg$out_maps_date, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$out_inter_maps_date, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$out_rds_date,  recursive = TRUE, showWarnings = FALSE)

# Create pass dirs ONLY for passes that exist
for (p in cfg$passes_available) {
  dir.create(cfg$out_maps_pass[[p]], recursive = TRUE, showWarnings = FALSE)
  dir.create(cfg$out_inter_maps_pass[[p]], recursive = TRUE, showWarnings = FALSE)
  dir.create(cfg$out_rds_pass[[p]],  recursive = TRUE, showWarnings = FALSE)
}

cat("00_config | date:", format(cfg$smap_date), "| granule:",
    ifelse(is.na(cfg$data_file), "NOT ON DISK", cfg$data_file),
    "| passes:", ifelse(length(cfg$passes_available) == 0, "none",
                        paste(cfg$passes_available, collapse = ",")), "\n")

# Fail early and clearly if there is nothing to work with for this date.
# (Later scripts read the CSVs, so a missing granule is fine once 02 has run.)
if (is.na(cfg$data_file) && length(cfg$passes_available) == 0) {
  stop("no SMAP granule and no processed CSVs for ", cfg$date_tag,
       ". Run: python fetch_smap.py ", format(cfg$smap_date), call. = FALSE)
}
