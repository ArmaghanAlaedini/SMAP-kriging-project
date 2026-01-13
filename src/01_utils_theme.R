# 01_utils_theme
# Theme + saving utilities

library(ggplot2)
library(grid)
library(leaflet) 
library(htmlwidgets)

# ---- save functions ----
# for static maps
save_both <- function(plot, name, outdir, width = 8, height = 4.8, units = "in", dpi = 300) {
  ggsave(
    filename = file.path(outdir, paste0(name, ".png")),
    plot = plot, width = width, height = height, units = units, dpi = dpi)
  ggsave(
    filename = file.path(outdir, paste0(name, ".pdf")),
    plot = plot, width = width, height = height, units = units, device = "pdf")}

# for interactive map
save_inter <- function(widget, name, outdir){
  saveWidget(widget, file.path(outdir, paste0(name, ".html")))}

# ---- SMAP theme ----
SMAP_theme <- function(base_size = 14, base_family = "") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      plot.background   = element_rect(fill = "white", color = NA),
      panel.background  = element_rect(fill = "white", color = NA),
      panel.grid        = element_blank(),
      
      axis.text         = element_text(color = "black"),
      axis.title        = element_text(color = "black"),
      plot.title        = element_blank(),
      
      legend.position   = "bottom",
      legend.direction  = "horizontal",
      legend.background = element_rect(fill = "white", color = NA),
      legend.key.height = unit(0.5, "cm"),
      legend.key.width  = unit(1.5, "cm"),
      legend.box.margin = margin(0, 0, 0, 0),
      
      plot.margin       = margin(10, 10, 10, 10)
    )}

# checked