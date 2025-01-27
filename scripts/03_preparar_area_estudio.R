library(tidyverse)
library(sf)
library(tmap)
library(terra)
library(geodata)
library(tidysdm)

tmap_mode('view')

# 1. Area de estudio vectorial ----
chl <- geodata::gadm('chile',level = 0,path = 'data/raw')
arg <- geodata::gadm('argentina',level = 0,path = 'data/raw')

area <- st_union(chl |> st_as_sf(),arg |> st_as_sf())
plot(area['geometry'],axes = TRUE)

area_sfg <- st_geometry(area)
bb <- st_bbox(area_sfg)
bb[1] <- -76

area_sfg <- st_crop(area_sfg,bb) 
write_rds(area,'data/processed/area_estudio.rds')

# 2. Raster del área de estudio ----

area_ras_chl <- geodata::worldclim_country('chile',var = 'bio',path = 'data/raw') 
area_ras_arg <- geodata::worldclim_country('argentina',var = 'bio',path = 'data/raw') 
area_ras <- merge(area_ras_chl,area_ras_arg)

area_ras <- crop(area_ras[[1]],area_sfg)
area_ras[!is.na(area_ras)] <- 1
names(area_ras) <- 'land'
plot(area_ras)

writeRaster(area_ras,'data/processed/area_estudio_raster.tif',overwrite  =TRUE)

