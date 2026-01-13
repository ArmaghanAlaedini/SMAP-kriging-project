# 05_plots
# Static plots (runs for AM + PM)

source("00_config.R")
source("01_utils_theme.R")

library(sf)
library(ggplot2)
library(grid) 

theme_set(SMAP_theme())

for (p in cfg$passes_available) {
  
  cat("\n========================\n")
  cat("03_kriging | PASS:", p, "\n")
  cat("========================\n")
  
  out_rds  <- cfg$out_rds_pass[[p]]
  out_maps <- cfg$out_maps_pass[[p]]
  
  f_cells <- file.path(out_rds, "cells_ease_detrended.rds")
  f_pred  <- file.path(out_rds, "twn_pred_type0.rds")
  f_twn   <- file.path(out_rds, "twnshp_type0.rds")
  
  if (!file.exists(f_cells) || !file.exists(f_pred) || !file.exists(f_twn)) {
    message("04_plots | PASS ", p, " skipped: missing inputs in ", out_rds)
    next
  }
  # load objects for plotting
  cells_ease <- readRDS(file.path(out_rds, "cells_ease_detrended.rds"))
  twn_pred   <- readRDS(file.path(out_rds, "twn_pred_type0.rds"))
  twnshp_type0  <- readRDS(file.path(out_rds, "twnshp_type0.rds"))
  
  # ------ observed SMAP pixels over Iowa ------ 
  SMAP_observations_in_IA <- ggplot() +
    geom_sf(data = cells_ease, aes(fill = soil_moisture), color = NA, linewidth = 0) +
    geom_sf(data = twnshp_type0, fill = NA, color = "white", linewidth = 0.15, alpha = 0.06) +
    scale_fill_viridis_c(name = "Observed soil moisture (m³/m³)", direction = -1,
      limits = cfg$lims_sm_global, guide = guide_colorbar(title.position = "top",
        title.hjust    = 0.5,
        barwidth       = unit(0.5, "npc"),
        barheight      = unit(0.35, "cm"))) + 
    coord_sf(expand = FALSE)
  SMAP_observations_in_IA
  save_both(SMAP_observations_in_IA, "SMAP_observed_Iowa", outdir = out_maps)
  
  # ------ observed SMAP pixels cropped over Iowa ----
  IA_union <- st_union(st_make_valid(twnshp_type0))
  cells_ease_clip <- st_intersection( st_make_valid(cells_ease[, "soil_moisture", drop = FALSE]), 
                                      IA_union)
  
  SMAP_observations_in_IA_clipped <- ggplot() +
    geom_sf(data = cells_ease_clip, aes(fill = soil_moisture),
            color = NA, linewidth = 0) +
    geom_sf(data = twnshp_type0, fill = NA, color = "white",
            linewidth = 0.15, alpha = 0.06, inherit.aes = FALSE) +
    scale_fill_viridis_c(name = "Observed soil moisture (m³/m³)", direction = -1,
      limits = cfg$lims_sm_global, guide = guide_colorbar(title.position = "top",
        title.hjust    = 0.5,
        barwidth       = unit(0.5, "npc"),
        barheight      = unit(0.35, "cm"))) + coord_sf(expand = FALSE)
  
  SMAP_observations_in_IA_clipped
  save_both(SMAP_observations_in_IA_clipped, "SMAP_observed_Iowa_clipped", outdir = out_maps)
  
  # ------ predicted soil moisture over Iowa ------ 
  Kriging_Prediction_in_IA <- ggplot(twn_pred) +
    geom_sf(aes(fill = pred_final), color = "white", linewidth = 0) +
    scale_fill_viridis_c(
      name = "Predicted soil moisture (m³/m³)",
      direction = -1,
      limits = cfg$lims_sm_global, guide = guide_colorbar(title.position = "top",
        title.hjust    = 0.5,
        barwidth       = unit(0.5, "npc"),
        barheight      = unit(0.35, "cm"))) + 
    coord_sf(expand = FALSE)
  Kriging_Prediction_in_IA
  save_both(Kriging_Prediction_in_IA, "SMAP_predicted_townships_Iowa", outdir = out_maps)
  
  # ------  SD plot of predictions ------ 
  IA_SD_uncertainty <- ggplot(twn_pred) +
    geom_sf(aes(fill = sd_krig), color = "white", linewidth = 0) +
    scale_fill_viridis_c(
      name = "Kriging standard deviation",
      direction = -1, guide = guide_colorbar(title.position = "top",
        title.hjust    = 0.5,
        barwidth       = unit(0.5, "npc"),
        barheight      = unit(0.35, "cm"))) +
    coord_sf(expand = FALSE)
  IA_SD_uncertainty
  save_both(IA_SD_uncertainty, "SMAP_uncertainty_sd_townships", outdir = out_maps)
  
  # ------ township plot by area ------ 
  Iowa_townships_size <- ggplot(twn_pred) +
    geom_sf(aes(fill = area_km2), color = NA, linewidth = 0) +
    scale_fill_viridis_c(name = "Area (km²)", direction = 1, guide = guide_colorbar(title.position = "top",
        title.hjust    = 0.5,
        barwidth       = unit(0.5, "npc"),
        barheight      = unit(0.35, "cm"))) +
    coord_sf(expand = FALSE)
  Iowa_townships_size
  save_both(Iowa_townships_size, "Iowa_townships_area_km2", outdir = out_maps)
}

#checked