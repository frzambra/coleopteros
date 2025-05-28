library(tmap)
library(terra)
library(rnaturalearth)

chl <- rnaturalearth::ne_countries(scale ='medium',country='chile',returnclass = 'sv')

preds <- rast('data/processed/raster_predicciones_1970-2000_2061-2080.tif')
names(preds)[1:2] <- c('1971-2000','2061-2080')

map <-   tm_basemap('OpenStreetMap') +
 tm_shape(subset(preds,1:2)) + 
  tm_raster(col.scale = tm_scale_intervals(
    style = 'fisher',
    values = "arches",
                                            midpoint = NA),
            col.free = c(FALSE,FALSE),
            col.legend = tm_legend(title = 'Probability',
                                   orientation = 'landscape',
                                   width = 33,
                                   height = 13,
                                   title.size = 20,
                                   text.size = 12,
                                   frame = FALSE,
                                   frame.lwd = 0),
    col_alpha = .7
            
            ) +
  tm_shape(chl) +
  tm_borders() +
  tm_facets(nrow=1,orientation = 'horizontal') +
  tm_layout(panel.label.bg.color = 'white')

tmap_save(map,'output/figs/mapa_sdm_frickius_actual_proy.png',scale=.7,dpi = 300)
