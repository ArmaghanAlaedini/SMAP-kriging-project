# 02_smap_hdf5
# Transform HDF5 to CSV in a .gz file

source("00_config.R")
library(rhdf5)

data_path <- file.path(cfg$data_dir, cfg$data_file)
save_path <- file.path(cfg$smap_dir)

stopifnot(file.exists(data_path))
dir.create(save_path, recursive = TRUE, showWarnings = FALSE)

date_of_data <- cfg$date_tag # date substring of data file

h5ls(data_path, recursive = FALSE)

groups <- c(
  AM = "Soil_Moisture_Retrieval_Data_AM",
  PM = "Soil_Moisture_Retrieval_Data_PM")

dat <- list()

for (i in names(groups)) {
  
  grp <- groups[[i]]
  
  # dataset names (PM has _pm, AM does not)
  sm_name  <- if (i == "PM") "soil_moisture_pm" else "soil_moisture"
  lat_name <- if (i == "PM") "latitude_pm"      else "latitude"
  lon_name <- if (i == "PM") "longitude_pm"     else "longitude"
  
  # build dataset paths
  p_sm  <- paste0("/", grp, "/", sm_name)
  p_lat <- paste0("/", grp, "/", lat_name)
  p_lon <- paste0("/", grp, "/", lon_name)
  
  # read datasets
  dat[[i]] <- list(
    soil_moisture = h5read(data_path, p_sm),
    latitude      = h5read(data_path, p_lat),
    longitude     = h5read(data_path, p_lon)
  )
  
  # read attributes for soil moisture
  dat[[i]]$attrs_sm <- h5readAttributes(data_path, p_sm)
  
  cat("\n---", i, "soil_moisture attributes ---\n")
  print(dat[[i]]$attrs_sm)
  
  cat("\n", i, "dims:\n",
      "  soil_moisture:", paste(dim(dat[[i]]$soil_moisture), collapse = " x "), "\n",
      "  latitude     :", paste(dim(dat[[i]]$latitude), collapse = " x "), "\n",
      "  longitude    :", paste(dim(dat[[i]]$longitude), collapse = " x "), "\n")
  
  # pull cleaning params from attrs
  fill_value <- as.numeric(dat[[i]]$attrs_sm[["_FillValue"]])
  valid_min  <- as.numeric(dat[[i]]$attrs_sm[["valid_min"]])
  valid_max  <- as.numeric(dat[[i]]$attrs_sm[["valid_max"]])
  
  sm <- dat[[i]]$soil_moisture
  
  mask_fill <- (sm == fill_value)
  mask_out  <- (sm < valid_min) | (sm > valid_max)
  
  sm_clean <- sm
  sm_clean[mask_fill | mask_out] <- NA_real_
  
  dat[[i]]$soil_moisture_clean <- sm_clean
  
  cat("\n", i, "invalid cells -> fill:", sum(mask_fill, na.rm = TRUE),
      " range:", sum(mask_out, na.rm = TRUE), "\n")
  
  # long table indices
  nr <- nrow(sm_clean) # number of grid rows
  nc <- ncol(sm_clean) # number of grid cols
  
  rows <- rep(0:(nr - 1), each  = nc)
  cols <- rep(0:(nc - 1), times = nr)
  
  # build long dataframe
  df_long <- data.frame(
    row          = as.integer(rows),
    col          = as.integer(cols),
    latitude     = as.numeric(as.vector(t(dat[[i]]$latitude))),
    longitude    = as.numeric(as.vector(t(dat[[i]]$longitude))),
    soil_moisture= as.numeric(as.vector(t(sm_clean)))
  )
  
  stopifnot(nrow(df_long) == nr * nc)

  df_long <- df_long[!is.na(df_long$soil_moisture), ] # to save space
  
  # save
  out_csv <- file.path(save_path, sprintf("sm_%s_%s.csv.gz", date_of_data, i))
  write.csv(df_long, gzfile(out_csv), row.names = FALSE)
  cat("Saved:", out_csv, "\n")
}

H5close()

#checked