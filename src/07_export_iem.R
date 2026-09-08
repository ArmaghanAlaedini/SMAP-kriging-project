# 07_export_iem.R
# Flatten the township kriging predictions into one tidy CSV per date.
# This is the file IEM ingests. Everything upstream is your business,
# everything downstream is Daryl's.

source("00_config.R")

library(sf)

dir.create(cfg$out_iem, recursive = TRUE, showWarnings = FALSE)

# Pull township attributes from the saved shapefile object if the prediction
# table did not carry them through the kriging merge.
attach_township_names <- function(x, out_rds) {
  need <- c("POLITWP_ID", "CO_NAME", "TWP_NAME")
  if (all(need %in% names(x))) return(x)

  f_twn <- file.path(out_rds, "twnshp_type0.rds")
  if (!file.exists(f_twn)) {
    warning("no twnshp_type0.rds to recover township names from")
    for (n in need) if (!n %in% names(x)) x[[n]] <- NA
    return(x)
  }

  twn <- sf::st_drop_geometry(readRDS(f_twn))
  twn$TID <- twn$POLITWP_ID
  merge(x, twn[, c("TID", need)], by = "TID", all.x = TRUE, sort = FALSE)
}

parts <- list()

for (p in cfg$passes_available) {

  out_rds <- cfg$out_rds_pass[[p]]
  f_pred  <- file.path(out_rds, "twn_pred_type0.rds")

  if (!file.exists(f_pred)) {
    message("07_export_iem | PASS ", p, " skipped: no twn_pred_type0.rds")
    next
  }

  x <- readRDS(f_pred)
  if (inherits(x, "sf")) x <- sf::st_drop_geometry(x)
  x <- attach_township_names(x, out_rds)

  parts[[p]] <- data.frame(
    valid_date  = format(cfg$smap_date, "%Y-%m-%d"),
    pass        = p,
    politwp_id  = x$POLITWP_ID,
    county      = x$CO_NAME,
    township    = x$TWP_NAME,
    sm_est      = round(as.numeric(x$pred_final), 4),
    sm_krige_sd = round(as.numeric(x$sd_krig),    4),
    area_km2    = round(as.numeric(x$area_km2),   2),
    stringsAsFactors = FALSE
  )
}

if (length(parts) == 0) {
  message("07_export_iem | nothing to export for ", cfg$date_tag)
} else {

  out <- do.call(rbind, parts)
  out <- out[order(out$pass, out$politwp_id), ]

  f_out <- file.path(cfg$out_iem, sprintf("smap_townships_%s.csv", cfg$date_tag))
  f_tmp <- paste0(f_out, ".tmp")

  # Write to a temp name and rename, so a consumer polling the directory
  # never sees a half written file.
  write.csv(out, f_tmp, row.names = FALSE, na = "")
  file.rename(f_tmp, f_out)

  cat("07_export_iem | wrote", nrow(out), "rows to", f_out, "\n")
}