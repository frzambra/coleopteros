library(tidyverse)
library(tidyterra)
library(terra)

area_estudio_raster <- rast('data/processed/area_estudio_raster.tif')

# 3. Preparar datos de presencia ----
data <- read_csv('data/processed/Datos-consolidados_Fvariolosus_20241013.csv')

data_sf <- data |> 
  st_as_sf(coords = c('decimalLongitude','decimalLatitude'),crs = 4326)

set.seed(864)
data_full <- sample_pseudoabs(data_sf,area_estudio_raster,
                                n=nrow(data_sf)*3,method = c('dist_min',500))
write_rds(data_full,'data/processed/datos_ausencia-presencia.rds')

ggplot() +
  geom_spatraster(data = area_estudio_raster,
                  aes(fill = land)) +
  geom_sf(data = data_full,aes(col = class)) +
  guides('none')
  


# dejar sólo un punto pot celda
data <- thin_by_cell(data_sf,raster = area_ras)

#eliminar los puntos que estén a un distancia de 1000
#


# 3. Prepara datos de pseudo-ausencia
