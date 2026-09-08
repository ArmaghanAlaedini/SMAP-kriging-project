#!/usr/bin/env Rscript
# run_day.R -- run the whole pipeline for one observation date.
#
#   Rscript run_day.R 2026-09-07
#
# Set SMAP_FORCE=1 to re-run a date whose output already exists.
# Set SMAP_NO_INTERACTIVE=1 to skip the Leaflet HTML step.
# Assumes fetch_smap.py has already put the .h5 in data/raw_data.

suppressPackageStartupMessages(library(here))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("usage: Rscript run_day.R YYYY-MM-DD", call. = FALSE)

smap_date <- as.Date(args[1], format = "%Y-%m-%d")
if (is.na(smap_date)) stop("bad date: ", args[1], call. = FALSE)

date_tag <- format(smap_date, "%Y%m%d")
Sys.setenv(SMAP_DATE = format(smap_date, "%Y-%m-%d"))

# here() caches the project root on first call, so resolve it before setwd()
root <- here::here()

final_out <- file.path(root, "output", "iem",
                       sprintf("smap_townships_%s.csv", date_tag))

if (file.exists(final_out) && !nzchar(Sys.getenv("SMAP_FORCE"))) {
  message("run_day | already done: ", final_out)
  quit(save = "no", status = 0)
}

# Remove directories that contain no files, deepest first. 00_config.R creates
# a folder for every available pass up front, and a pass that gets skipped
# (too few retrievals) leaves an empty one behind.
prune_empty_dirs <- function(root_dir) {
  if (!dir.exists(root_dir)) return(invisible(NULL))
  dirs <- list.dirs(root_dir, recursive = TRUE, full.names = TRUE)
  dirs <- dirs[dirs != root_dir]
  for (d in rev(sort(dirs))) {
    if (!dir.exists(d)) next
    if (length(list.files(d, all.files = TRUE, no.. = TRUE)) == 0L) {
      unlink(d, recursive = TRUE)
    }
  }
  invisible(NULL)
}

setwd(file.path(root, "src"))

# atakrig draws diagnostic plots (deconvPointVgm has fig = TRUE). With no
# display attached that either errors or writes a stray Rplots.pdf every day.
# Opening a null device absorbs them, so no edits to 04_kriging.R are needed.
if (!interactive()) {
  grDevices::pdf(NULL)
  on.exit(try(grDevices::dev.off(), silent = TRUE), add = TRUE)
}

steps <- c(
  "02_smap_hdf5.R",
  "03_detrend.R",
  "04_kriging.R",
  "05_plots.R",
  "06_interactive_plot.R",
  "07_export_iem.R"
)

# 06 is safe under Rscript: its shinyApp() call is guarded by if (interactive()),
# and the HTML widgets are written separately. Skip it if you want faster runs.
if (nzchar(Sys.getenv("SMAP_NO_INTERACTIVE"))) {
  steps <- setdiff(steps, "06_interactive_plot.R")
}

t_all <- Sys.time()

for (s in steps) {
  message("\n>>> ", s, "  [", format(Sys.time(), "%H:%M:%S"), "]")
  t0 <- Sys.time()
  ok <- tryCatch({ source(s, echo = FALSE); TRUE },
                 error = function(e) { message("FAILED in ", s, ": ", conditionMessage(e)); FALSE })
  if (!ok) {
    prune_empty_dirs(file.path(root, "output"))
    quit(save = "no", status = 1)
  }
  message("<<< ", s, " ok in ",
          round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 2), " min")
}

prune_empty_dirs(file.path(root, "output"))

message("\nrun_day | ", date_tag, " complete in ",
        round(as.numeric(difftime(Sys.time(), t_all, units = "mins")), 1), " min")