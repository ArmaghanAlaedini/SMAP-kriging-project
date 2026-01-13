# 04_kriging.R
# Kriging process: semivariogram + deconvolution + kriging (runs for AM + PM)

source("00_config.R")

library(sf)
library(atakrig)
library(dplyr)

for (p in cfg$passes_available) {
  
  cat("\n========================\n")
  cat("03_kriging | PASS:", p, "\n")
  cat("========================\n")
  
  out_rds  <- cfg$out_rds_pass[[p]]
  
  in_cells <- file.path(out_rds, "cells_ease_detrended.rds")
  
  # for datasets that do not pass over Iowa
  if (!file.exists(in_cells)) {
    cat("SKIP:", p, "because missing:", in_cells, "\n")
    next
  }
  
  # loading detrended output (PASS-specific)
  cells_ease <- readRDS(in_cells)
  
  # discretizing
  sm_discrete <- discretizePolygon(
    cells_ease,
    cellsize = cfg$disc_obs,
    id = "pixel_id",
    value = "sm_for_kriging",
    showProgressBar = TRUE
  )
  
  # deconvolution
  point_smvg <- deconvPointVgm(
    sm_discrete,
    model = cfg$vgm_model,
    ngroup = cfg$ngroup,
    rd = cfg$rd,
    # maxIter = cfg$maxIter,
    # maxSampleNum = cfg$maxSampleNum,
    fig = TRUE
  )
  
  saveRDS(point_smvg, file.path(out_rds, paste0("point_smvg_", cfg$vgm_model, ".rds")))
  cat("Saved point_smvg to:", out_rds, "\n")
  
  # read and prepare Iowa townships (same for both passes, but saved into pass folder)
  twnshp <- st_read(cfg$townships_shp, quiet = TRUE) |>
    st_transform(cfg$crs_ease)
  
  saveRDS(twnshp, file.path(out_rds, "twnshp_type0.rds"))
  cat("Saved townships to:", out_rds, "\n")
  
  twnshp <- st_read(cfg$townships_shp, quiet = TRUE)
  # removing cities
  twnshp_type0 <- twnshp[twnshp$TYPE == 0, ] 
  twnshp_type0 <- st_make_valid(twnshp_type0)
  twnshp_type0 <- st_transform(twnshp_type0, crs = cfg$crs_ease)
  
  # columns needed for interactive map
  twnshp_type0_df <- st_sf(
    TID        = twnshp_type0$POLITWP_ID,  
    POLITWP_ID = twnshp_type0$POLITWP_ID,
    CO_NAME    = twnshp_type0$CO_NAME,
    TWP_NAME   = twnshp_type0$TWP_NAME,
    geometry   = st_geometry(twnshp_type0)
  )
  
  twn_discrete <- discretizePolygon(
    twnshp_type0_df,
    cellsize = cfg$disc_twn,
    id = "TID")
  
  # ATAkriging
  pred_tbl <- ataKriging(
    sm_discrete,
    twn_discrete,
    point_smvg$pointVariogram,
    showProgress = TRUE)
  
  # Ranaming key columns
  names(pred_tbl)[1] <- "TID"
  names(pred_tbl)[4] <- "pred_krig"
  names(pred_tbl)[5] <- "var_krig"
  pred_tbl$sd_krig <- sqrt(pred_tbl$var_krig)
  
  # adding the prediction to the dataset
  twn_pred <- merge(twnshp_type0_df, pred_tbl, by = "TID", all.x = TRUE, sort = FALSE)
  
  # adding the trend back if there was any
  trend_was_removed <- isTRUE(any(cells_ease$trend_removed))
  
  if (trend_was_removed) {
    
    message("Detrending was applied -> estimating township-level trend and adding it back.")
    
    sm_trend_discrete <- discretizePolygon(
      cells_ease,
      cellsize = cfg$disc_obs,
      id = "pixel_id",
      value = "trend_hat",
      showProgressBar = TRUE)
    
    trend_tbl <- ataKriging(
      sm_trend_discrete,
      twn_discrete,
      point_smvg$pointVariogram,
      showProgress = TRUE)
    
    names(trend_tbl)[1] <- "TID"
    names(trend_tbl)[4] <- "trend_twn"
    
    twn_pred <- merge(twn_pred, trend_tbl[, c("TID", "trend_twn")],
                      by = "TID", all.x = TRUE, sort = FALSE)
    
    twn_pred$pred_final <- twn_pred$pred_krig + twn_pred$trend_twn
    
  } else {
    
    message("No detrending applied -> pred_krig is already soil moisture prediction.")
    twn_pred$trend_twn  <- NA_real_
    twn_pred$pred_final <- twn_pred$pred_krig
  }
  
  # adding area for plotting
  twn_pred$area_km2 <- as.numeric(st_area(twn_pred)) / 1e6
  
  # saving outputs for plotting
  saveRDS(twn_pred, file.path(out_rds, "twn_pred_type0.rds"))
  saveRDS(twnshp_type0, file.path(out_rds, "twnshp_type0.rds"))
  
}

#checked