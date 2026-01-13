# 00_config.R
# Project settings + folder structure

library(here)

cfg <- list(
  
  # ---- OUTPUT ROOTS ----
  out_root = here("output"),
  out_maps = here("output", "maps"),
  out_int_maps = here("output", "interactive maps"),
  out_rds  = here("output", "rds"),
  
  # ---- INPUTS ----
  data_dir      = here("data", "raw_data"),
  smap_dir      = here("data", "SMAP_csv"),
  townships_dir = here("data", "civil_townships"),
  
  data_file     = "SMAP_L3_SM_P_E_20251024_R19240_002.h5",
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

# Date tag (8-digit date in file name)
m <- regexpr("\\d{8}", cfg$data_file)
cfg$date_tag <- if (m[1] > 0) regmatches(cfg$data_file, m) else substr(cfg$data_file, 16, 23)

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

#checked