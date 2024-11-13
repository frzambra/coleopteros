#Preparar predictores

library(tidyverse)
library(sf)
library(tmap)
library(fs)
library(terra)
library(climateR)

data <-  read_csv('data/processed/Datos-consolidados_Fvariolosus_20241013.csv') |> 
  select(1:7) |> 
  st_as_sf(coords =c('decimalLongitude','decimalLatitude'),crs=4326) 

bb <- st_bbox(data) 
bb[1] <- -76
bb[2] <- -56
bb[3] <- -68
bb <- bb |> st_as_sfc()

biomas <- rast('~/Descargas/chile_coverage_2022.tif')

biomas <-  crop(biomas,bb)
plot(biomas)
writeRaster(biomas,'~/Descargas/biomas.tif')
