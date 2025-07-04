library(tidyverse)
library(tidyterra)
library(terra)
library(sf)

area_estudio_raster <- rast('data/processed/area_estudio_raster.tif')

# 3. Preparar datos de presencia ----
data <- read_csv('data/processed/Datos-consolidados_Fvariolosus_20241013.csv') |> 
  select(c(1:2,4:6))

data_sf <- data |> 
  st_as_sf(coords = c('decimalLongitude','decimalLatitude'),crs = 4326)

# disminuir muestras para tener una por pixel

data_pres <- thin_by_cell(data_sf, raster = area_estudio_raster)

# disminuir muestras que esten a menos de 500 metros
data_pres <- thin_by_dist(data_pres,dist_min = 500)

set.seed(864)
data_full <- sample_pseudoabs(data_pres,
                              area_estudio_raster,
                              n = nrow(data_sf)*3,
                              method = c('dist_min',1000))

write_rds(data_full,'data/processed/datos_ausencia-presencia.rds')

summary(data_full)
ggplot() +
  geom_spatraster(data = area_estudio_raster,
                  aes(fill = land)) +
  geom_sf(data = data_full,aes(col = class)) +
  guides('none') +
  theme_bw()
  

