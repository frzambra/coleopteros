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

# Mapbiomas ----
biomas <- rast('data/raw/rasters/chile_coverage_2022.tif')
biomas <-  crop(biomas,bb)

# Clima Normal ----

## humedad de suelo

sm <- rast('data/raw/rasters/TerraClimate19912020_soil.nc')
sm_bb <- crop(sm,bb)

## temperatura máxima
tmax <- rast('data/raw/rasters/TerraClimate19912020_tmax.nc')
tmax_bb <- crop(tmax,bb)

## temperatura máxima
tmin <- rast('data/raw/rasters/TerraClimate19912020_tmin.nc')
tmin_bb <- crop(tmin,bb)

## actual evapotrasnpiration
aet <- rast('data/raw/rasters/TerraClimate19912020_aet.nc')
aet_bb <- crop(aet,bb)

# Elevación ----

library(geodata)
dem_chl <- elevation_30s(country = 'chile',path = tempdir())
dem_arg <- elevation_30s(country = 'argentina',path = tempdir())

dem <- merge(dem_chl,dem_arg)
dem <- crop(dem,bb)

slp <- terrain(dem,v = 'slope',unit = 'radians')
asp <- terrain(dem,v = 'aspect',unit = 'radians')

elev_fea <- c(dem,slp,asp) 

# unir predictores ----

## resamplear biomas y elev_fea

biomas <- resample(biomas,tmin,method = 'near')
biomas <- trim(biomas)

elev_fea <- resample(elev_fea,tmin,method = 'bilinear')
elev_fea <- crop(elev_fea,bb)
names(elev_fea)[1] <- 'dem'

names(biomas) <- 'mapbiomas_2022'
crs(biomas) <- crs(sm_bb)
crs(elev_fea) <- crs(sm_bb)
preds <- c(biomas,elev_fea,sm_bb,tmax_bb,tmin_bb,aet_bb)
plot(preds)

# guardar predictores ----
writeRaster(preds,'data/raw/rasters/predictores.tif')
