# 05_interactive_plots
# HTML file + Shiny app for interactive prediction map (runs for AM + PM)

<<<<<<< HEAD
theme_set(SMAP_theme())
=======
>>>>>>> 128a143 (Codes added)
source("00_config.R")
source("01_utils_theme.R")

library(shiny)
library(shinythemes)
library(sf)
library(leaflet)
library(htmltools)
library(htmlwidgets)
library(viridisLite)

# helper functions
# load predictions for a pass if they exist
read_twn_pred_pass <- function(pass) {
  out_rds <- cfg$out_rds_pass[[pass]]
  f_pred  <- file.path(out_rds, "twn_pred_type0.rds")
  
  if (!file.exists(f_pred)) return(NULL)
  
  x <- readRDS(f_pred)
  
  # leaflet expects lon/lat coordinates (EPSG:4326)
  x <- st_make_valid(x)
  x <- st_transform(x, cfg$crs_wgs84)
  
  x
}

# build the Leaflet widget
build_leaflet_pred <- function(twn_pred_ll) {
  
  # color scale matches viridis direction = -1 and global limits
  pal <- colorNumeric(
    palette = viridisLite::viridis(256, direction = -1),
    domain  = cfg$lims_sm_global,
    na.color = "transparent"
  )

  # hover text (label) — HTML so it looks clean
  labels <- sprintf(
    "<b>%s Township</b><br/><b>County:</b> %s<br/><b>Predicted SM:</b> %.3f<br/><b>SD:</b> %.3f<br/><b>Area:</b> %.1f km²",
    twn_pred_ll$TWP_NAME, twn_pred_ll$CO_NAME,
    twn_pred_ll$pred_final, twn_pred_ll$sd_krig, twn_pred_ll$area_km2
  ) |> lapply(htmltools::HTML)
  
  leaflet(twn_pred_ll, options = leafletOptions(zoomControl = TRUE)) |>
    addProviderTiles("CartoDB.Positron") |>
    addPolygons(
      fillColor   = ~pal(pred_final),
      fillOpacity = 0.85,
      color       = "white",
      weight      = 0.5,
      opacity     = 1,
      label       = labels,
      highlightOptions = highlightOptions(
        weight = 2,
        color  = "#000000",
        bringToFront = TRUE
      )
    ) |>
    addLegend(
      position = "bottomright",
      pal      = pal,
      values   = ~pred_final,
      title    = "Predicted soil moisture (m³/m³)",
      opacity  = 0.9
    )
}

# plotting
# save HTML maps (one per available pass)

for (p in cfg$passes_available) {
  
  twn_pred <- read_twn_pred_pass(p)
  if (is.null(twn_pred)) {
    message("06_interactive_plots | PASS ", p, " skipped: missing twn_pred_type0.rds")
    next
  }
  
  widget <- build_leaflet_pred(twn_pred)
  
  out_int <- cfg$out_inter_maps_pass[[p]]
  dir.create(out_int, recursive = TRUE, showWarnings = FALSE)
  
  # saving with save_inter from 01_utils_theme.R
  save_inter(
    widget,
    name  = paste0("SMAP_township_pred_type0_", cfg$date_tag, "_", p),
    outdir = out_int
  )
  
  message("Saved interactive HTML for ", p, " into: ", out_int)
}

# Shiny app (interactive pass selection + download button)
ui <- fluidPage(
  theme = shinythemes::shinytheme("flatly"),
  
  tags$style(HTML("
    body { background-color: white; }
    .well { background-color: white; border-radius: 10px; }")),
  
  titlePanel(paste0("SMAP Township Predictions — ", cfg$date_tag)),
  
  sidebarLayout(
    sidebarPanel(
      # Pass dropdown only shows what exists (AM/PM or just one)
      selectInput("pass", "Pass (AM/PM)", choices = cfg$passes_available),
      
      helpText("Hover over townships to see the details."),
      
      hr(),
      
      # Download GeoPackage
      downloadButton("download_gpkg", "Download map")
    ),
    
    mainPanel(
      leafletOutput("map", height = 720),
      br(),
      verbatimTextOutput("status")
    )
  )
)

server <- function(input, output, session) {
  
  twn_pred_reactive <- reactive({
    dat <- read_twn_pred_pass(input$pass)
    validate(
      need(!is.null(dat), "Missing twn_pred_type0.rds for this pass.")
    )
    dat
  })
  
  output$map <- renderLeaflet({
    build_leaflet_pred(twn_pred_reactive())
  })
  
  output$status <- renderText({
    out_int <- cfg$out_inter_maps_pass[[input$pass]]
    paste0(
      "File name starts with:\n",
      "SMAP_township_pred_type0_", cfg$date_tag, "_", input$pass
    )
  })
  
  output$download_gpkg <- downloadHandler(
    filename = function() {
      paste0("twn_pred_type0_", cfg$date_tag, "_", input$pass, ".gpkg")
    },
    content = function(file) {
      dat <- twn_pred_reactive()
      
      # Write a single layer named "twn_pred_type0"
      st_write(dat, file, layer = "twn_pred_type0", delete_dsn = TRUE, quiet = TRUE)
    }
  )
}

if (interactive()) shinyApp(ui, server)

#checked
