# 03_detrend.R
# Trend check + residuals (runs for AM + PM)

source("00_config.R")

library(sf)

for (p in cfg$passes_available) {
  
  cat("\n========================\n")
  cat("02_detrend | PASS:", p, "\n")
  cat("========================\n")
  
  in_csv  <- cfg$smap_csv_pass[[p]]
  out_rds <- cfg$out_rds_pass[[p]]
  
  stopifnot(file.exists(in_csv))
  
  # read subset for Iowa
  df <- read.csv(in_csv, stringsAsFactors = TRUE)
  
  # if an index column was written as X, rename it to ID
  if ("X" %in% names(df)) names(df)[names(df) == "X"] <- "ID"
  
  df <- na.omit(df)
  
  # approximate coordination for Iowa
  SMAP_IA <- subset(df,
                    longitude >= -97 & longitude <= -89 &
                      latitude  >=  40 & latitude  <=  44
  )
  
  if (nrow(SMAP_IA) == 0) {
    message("No Iowa observations for pass ", p, " — skipping.")
    next
  }
  
  # crs conversion
  pts_wgs84 <- st_as_sf(SMAP_IA, coords = c("longitude", "latitude"),
                        crs = cfg$crs_wgs84, remove = FALSE)
  pts_ease <- st_transform(pts_wgs84, crs = cfg$crs_ease)
  
  # making pixel polygons + 4.5 km to each direction to find polygons from centroids
  half <- cfg$smap_cellsize / 2
  make_square <- function(x, y, h) {
    st_polygon(list(matrix(c(
      x-h, y-h,
      x+h, y-h,
      x+h, y+h,
      x-h, y+h,
      x-h, y-h
    ), ncol = 2, byrow = TRUE)))
  }
  
  xy <- st_coordinates(pts_ease)
  polys <- st_sfc(
    lapply(seq_len(nrow(pts_ease)), \(i) make_square(xy[i,1], xy[i,2], half)),
    crs = cfg$crs_ease)
  
  cells_ease <- st_sf(
    pixel_id      = seq_len(nrow(pts_ease)),
    soil_moisture = pts_ease$soil_moisture,
    geometry      = polys)
  
  # x and y from centroids
  cxy <- st_coordinates(st_centroid(cells_ease))
  cells_ease$x <- cxy[, 1]
  cells_ease$y <- cxy[, 2]
  
  # trend checking
  m0 <- lm(soil_moisture ~ 1, data = cells_ease)
  
  m_start <- lm(soil_moisture ~ x + y + I(x^2) + I(y^2) + I(x*y), data = cells_ease)
  
  m_sel <- step(
    m_start,
    direction = "backward",
    scope = list(lower = ~ x + y, upper = ~ x + y + I(x^2) + I(y^2) + I(x*y)),
    trace = 0
  )
  
  trend_test <- anova(m0, m_sel)
  p_trend <- trend_test[2, "Pr(>F)"]
  r2_trend <- summary(m_sel)$r.squared
  
  cells_ease$pass <- p
  cells_ease$p_trend <- p_trend
  cells_ease$r2_trend <- r2_trend
  
  r2_threshold <- 0.01
  
  if (!is.na(p_trend) && p_trend < 0.05 && r2_trend > r2_threshold) {
    trend_fit <- m_sel
    cells_ease$trend_hat <- predict(trend_fit, newdata = cells_ease)
    cells_ease$resid <- cells_ease$soil_moisture - cells_ease$trend_hat
    cells_ease$sm_for_kriging <- cells_ease$resid
    cells_ease$trend_removed <- TRUE
  } else {
    trend_fit <- m0
    cells_ease$trend_hat <- as.numeric(coef(m0)[1])
    cells_ease$resid <- cells_ease$soil_moisture - cells_ease$trend_hat
    cells_ease$sm_for_kriging <- cells_ease$soil_moisture
    cells_ease$trend_removed <- FALSE
  }
  
  # save into PASS folder
  saveRDS(trend_fit,  file.path(out_rds, "trend_fit.rds"))
  saveRDS(trend_test, file.path(out_rds, "trend_test.rds"))
  saveRDS(cells_ease, file.path(out_rds, "cells_ease_detrended.rds"))
  
  cat("Saved RDS into:", out_rds, "\n")
}

#checked