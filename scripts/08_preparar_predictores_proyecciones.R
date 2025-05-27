# Preparar predictores con proyecciones climáticas

# 0.- Cargar paquetes
library(geodata)
library(terra)
library(sf)
library(tidyverse) 
# 
# 1.- Cargar area de estudio ----
aestudio <- read_rds('data/processed/area_estudio.rds')

# 2.- Cargar variables bioclimáticas worldclim ----

# Elección del modelo de proyección basado en
# Salazar, Á., Thatcher, M., Goubanova, K. et al. CMIP6 precipitation and temperature projections for Chile. Clim Dyn 62, 2475–2498 (2024). https://doi.org/10.1007/s00382-023-07034-9
# 
# cent <- st_centroid(aestudio) |> st_coordinates() |> st_drop_geometry()
# biopro <- geodata::cmip6_tile(lat = cent[1,2],lon=cent[1,1],
#                               model = "AWI-CM-1-1-MR",
#                               ssp="585",time = "2061-2080",
#                               var = 'bioc',
#                               path = 'data/raw')

#descargado para todo el mundo de forma manual
bio_spp585 <- rast('/mnt/data_raw/CMIP6/wc2.1_30s_bioc_AWI-CM-1-1-MR_ssp585_2061-2080.tif')

bio_spp585 <- crop(bio_spp585,aestudio)

#cargar los predictores con los que se creo el modelo

preds <- rast('/mnt/data_procesada/papers/frickius_SDM/todos_los_predictores.tif')

preds_proj <- c(subset(preds,1:3),bio_spp585,subset(preds,23:63))

names(preds_proj)[4:22] <- paste0('bio_',1:19)
writeRaster(preds_proj,'/mnt/data_procesada/papers/frickius_SDM/todos_los_predictores_proyecciones.tif',overwrite = TRUE)
