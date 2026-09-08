# 06_interactive_plots
# Interactive maps with two selections: pass (AM/PM) and layer
# (observed SMAP pixels clipped to Iowa, or ATA-kriged townships).
#
# The observed layer is read from cells_ease_detrended.rds, which 03_detrend.R
# writes before kriging runs. So a pass whose variogram fit failed, or that was
# skipped for having too few retrievals, still shows its actual pixels.
#
# Writes ONE html per date containing every available combination, selectable
# through Leaflet's layers control. The Shiny app offers the same choices as
# dropdowns.

source("00_config.R")
source("01_utils_theme.R")

library(shiny)
library(shinythemes)
library(sf)
library(leaflet)
library(htmltools)
library(htmlwidgets)
library(viridisLite)

# ---- Iowa outline, computed once and reused ----------------------------------
# Read the shapefile directly rather than twnshp_type0.rds, because that file is
# only written by 04_kriging.R and will be absent for a pass that was skipped.

iowa_union <- local({
  twn <- sf::st_read(cfg$townships_shp, quiet = TRUE)
  twn <- twn[twn$TYPE == 0, ]
  sf::st_union(sf::st_make_valid(twn))
})

# ---- loaders -----------------------------------------------------------------

# observed SMAP pixels for a pass, clipped to Iowa, in lon/lat
read_obs_pass <- function(pass) {
  f <- file.path(cfg$out_rds_pass[[pass]], "cells_ease_detrended.rds")
  if (!file.exists(f)) return(NULL)

  x <- readRDS(f)
  if (!nrow(x)) return(NULL)

  x <- sf::st_make_valid(x)

  # clip to the state outline; both are on cfg$crs_ease at this point
  clipped <- try(
    suppressWarnings(sf::st_intersection(x, sf::st_transform(iowa_union, sf::st_crs(x)))),
    silent = TRUE
  )
  if (inherits(clipped, "try-error") || !nrow(clipped)) return(NULL)

  sf::st_transform(clipped, cfg$crs_wgs84)
}

# ATA-kriged township predictions for a pass, in lon/lat
read_twn_pred_pass <- function(pass) {
  f <- file.path(cfg$out_rds_pass[[pass]], "twn_pred_type0.rds")
  if (!file.exists(f)) return(NULL)

  x <- readRDS(f)
  x <- sf::st_make_valid(x)
  sf::st_transform(x, cfg$crs_wgs84)
}

# ---- shared colour scale -----------------------------------------------------
# Observed and predicted are the same quantity on the same limits, so one
# palette and one legend serve every layer.

sm_pal <- colorNumeric(
  palette  = viridisLite::viridis(256, direction = -1),
  domain   = cfg$lims_sm_global,
  na.color = "transparent"
)

# ---- layer builders ----------------------------------------------------------

add_obs_layer <- function(map, dat, group) {
  labels <- sprintf(
    "<b>SMAP retrieval</b><br/><b>Soil moisture:</b> %.3f m³/m³",
    dat$soil_moisture
  ) |> lapply(htmltools::HTML)

  addPolygons(
    map,
    data        = dat,
    group       = group,
    fillColor   = ~ sm_pal(soil_moisture),
    fillOpacity = 0.85,
    color       = "white",
    weight      = 0.3,
    opacity     = 0.6,
    label       = labels,
    highlightOptions = highlightOptions(weight = 2, color = "#000000",
                                        bringToFront = TRUE)
  )
}

add_twn_layer <- function(map, dat, group) {
  labels <- sprintf(
    "<b>%s Township</b><br/><b>County:</b> %s<br/><b>Estimated SM:</b> %.3f<br/><b>SD:</b> %.3f<br/><b>Area:</b> %.1f km²",
    dat$TWP_NAME, dat$CO_NAME, dat$pred_final, dat$sd_krig, dat$area_km2
  ) |> lapply(htmltools::HTML)

  addPolygons(
    map,
    data        = dat,
    group       = group,
    fillColor   = ~ sm_pal(pred_final),
    fillOpacity = 0.85,
    color       = "white",
    weight      = 0.5,
    opacity     = 1,
    label       = labels,
    highlightOptions = highlightOptions(weight = 2, color = "#000000",
                                        bringToFront = TRUE)
  )
}

base_map <- function() {
  leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    # CARTO began watermarking keyless raster tiles in Aug 2026 and is retiring
    # that service, so use Esri's gray canvas instead.
    addProviderTiles("Esri.WorldGrayCanvas")
}

add_sm_legend <- function(map) {
  addLegend(
    map,
    position = "bottomright",
    pal      = sm_pal,
    values   = cfg$lims_sm_global,
    title    = "Soil moisture (m³/m³)",
    opacity  = 0.9
  )
}

# ---- what is available for this date ----------------------------------------

layer_labels <- c(observed = "Observed pixels", townships = "Estimated townships")

available <- list()
for (p in cfg$passes) {
  if (!p %in% cfg$passes_available) next
  obs <- read_obs_pass(p)
  twn <- read_twn_pred_pass(p)
  if (!is.null(obs)) available[[paste(p, "observed",  sep = "|")]] <- obs
  if (!is.null(twn)) available[[paste(p, "townships", sep = "|")]] <- twn
}

group_name <- function(key) {
  parts <- strsplit(key, "|", fixed = TRUE)[[1]]
  paste0(parts[1], " · ", layer_labels[[parts[2]]])
}

# ---- standalone HTML ---------------------------------------------------------

if (length(available) == 0) {

  message("06_interactive_plots | nothing to map for ", cfg$date_tag)

} else {

  m <- base_map()
  groups <- character(0)

  for (key in names(available)) {
    dat <- available[[key]]
    g   <- group_name(key)
    groups <- c(groups, g)
    m <- if (endsWith(key, "|observed")) add_obs_layer(m, dat, g) else add_twn_layer(m, dat, g)
  }

  bb <- as.numeric(sf::st_bbox(sf::st_transform(iowa_union, cfg$crs_wgs84)))

  m <- m |>
    addLayersControl(
      baseGroups = groups,
      options    = layersControlOptions(collapsed = FALSE)
    ) |>
    add_sm_legend() |>
    fitBounds(bb[1], bb[2], bb[3], bb[4])

  out_int <- cfg$out_inter_maps_date
  dir.create(out_int, recursive = TRUE, showWarnings = FALSE)

  save_inter(m, name = paste0("SMAP_interactive_", cfg$date_tag), outdir = out_int)

  message("06_interactive_plots | saved ", length(groups), " layer(s) into: ", out_int)
  message("06_interactive_plots | layers: ", paste(groups, collapse = ", "))
}

# ---- Shiny app ---------------------------------------------------------------

passes_present <- unique(vapply(strsplit(names(available), "|", fixed = TRUE),
                                `[`, character(1), 1))
layers_present <- unique(vapply(strsplit(names(available), "|", fixed = TRUE),
                                `[`, character(1), 2))

ui <- fluidPage(
  theme = shinythemes::shinytheme("flatly"),

  tags$style(HTML("
    body { background-color: white; }
    .well { background-color: white; border-radius: 10px; }")),

  titlePanel(paste0("SMAP Iowa soil moisture — ", cfg$date_tag)),

  sidebarLayout(
    sidebarPanel(
      selectInput("pass", "Pass", choices = passes_present),

      selectInput("layer", "Data",
                  choices = setNames(layers_present, layer_labels[layers_present])),

      helpText("Observed pixels are the raw SMAP retrievals clipped to Iowa. ",
               "Estimated townships are the ATA-kriging output, which is only ",
               "available when the variogram could be fitted."),

      hr(),

      downloadButton("download_gpkg", "Download layer")
    ),

    mainPanel(
      leafletOutput("map", height = 720),
      br(),
      verbatimTextOutput("status")
    )
  )
)

server <- function(input, output, session) {

  sel_key <- reactive(paste(input$pass, input$layer, sep = "|"))

  sel_data <- reactive({
    dat <- available[[sel_key()]]
    validate(need(
      !is.null(dat),
      paste0("No ", layer_labels[[input$layer]], " for the ", input$pass,
             " pass on ", cfg$date_tag, ".")
    ))
    dat
  })

  output$map <- renderLeaflet({
    dat <- sel_data()
    g   <- group_name(sel_key())
    m   <- base_map()
    m   <- if (input$layer == "observed") add_obs_layer(m, dat, g) else add_twn_layer(m, dat, g)
    add_sm_legend(m)
  })

  output$status <- renderText({
    dat <- available[[sel_key()]]
    if (is.null(dat)) {
      paste0("Not available for this combination.")
    } else {
      paste0(nrow(dat), " features · ", group_name(sel_key()), " · ", cfg$date_tag)
    }
  })

  output$download_gpkg <- downloadHandler(
    filename = function() {
      paste0("SMAP_", input$layer, "_", cfg$date_tag, "_", input$pass, ".gpkg")
    },
    content = function(file) {
      sf::st_write(sel_data(), file, layer = input$layer,
                   delete_dsn = TRUE, quiet = TRUE)
    }
  )
}

if (interactive()) shinyApp(ui, server)