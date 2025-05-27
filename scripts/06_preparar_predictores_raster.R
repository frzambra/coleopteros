library(terra)
library(sf)
library(tidyverse)
library(geodata)
library(fs)

# 1.- Cargar area de estudio ----
aestudio <- read_rds('data/processed/area_estudio.rds')

# 2.- Cargar variables bioclimáticas worldclim ----
# 
bio_chl <- geodata::worldclim_country('chile',var = 'bio',path = 'data/raw') 
bio_arg <- geodata::worldclim_country('argentina',var = 'bio',path = 'data/raw') 

bio <- merge(bio_chl,bio_arg) |> 
  crop(aestudio)

# 3. Variables de elevación ----

dem_chl <- elevation_30s('chile',path = 'data/raw')
dem_arg <- elevation_30s('argentina',path = 'data/raw')

dem <- merge(dem_chl,dem_arg)
slp <- terrain(dem,v = 'slope',unit = 'radians')
asp <- terrain(dem,v = 'aspect',unit = 'radians')

vars_dem <- c(dem,slp,asp)

vars_dem <- resample(vars_dem,bio)
names(vars_dem) <- c('dem','slope','aspect')
                      
# 4. Variables de paisaje ----

lcpers <- rast('/mnt/data_procesada/papers/frickius_SDM/IGBP80_reclassified.tif')

lcpers[is.na(lcpers)] <- 11

library(landscapemetrics)
check_landscape(lcpers)

lst_metrics <- lsm_abbreviations_names |> filter(level=='patch') |> pull(metric)
my_metric_r_all = spatialize_lsm(lcpers, level = "patch", 
                                 metric = lst_metrics,
                                 progress = TRUE
)

preds_lndsc_metrics <- my_metric_r_all$layer_1 |> rast()
writeRaster(preds_lndsc_metrics,
            '/mnt/data_procesada/papers/frickius_SDM/metricas_ldscp_lc_pers_2001-2023.tif',overwrite  =TRUE)

# preds_lndsc_metrics <- rast('/mnt/data_procesada/papers/frickius_SDM/metricas_ldscp_lc_pers_2001-2023.tif')

# 5. Variables de suelo ----

#Arcilla
clay <- terra::rast(dir_ls('/mnt/data_procesada/data/rasters/Procesados/SoilGRID250m/clay_chl/')[c(1,3,5)])
clay <- mean(clay,na.rm = TRUE)
clay <- project(clay,bio)
clay <- resample(clay,bio)

#Arena
sand <- terra::rast(dir_ls('/mnt/data_procesada/data/rasters/Procesados/SoilGRID250m/sand_chl/')[c(1,3,5)])
sand <- mean(sand,na.rm = TRUE)
sand <- project(sand,bio)
sand <- resample(sand,bio)

#Limo

silt <- terra::rast(dir_ls('/mnt/data_procesada/data/rasters/Procesados/SoilGRID250m/silt_chl/')[c(1,3,5)])
silt <- mean(silt,na.rm = TRUE)
silt <- project(silt,bio)
silt <- resample(silt,bio)

# AWC
# 
awc <- terra::rast(dir_ls('/mnt/data_procesada/data/rasters/Procesados/SoilGRID250m/awc_chl/')[c(1,3)])
awc <- mean(awc,na.rm = TRUE)
awc <- resample(awc,bio)

suelo <- c(clay,sand,silt,awc)
names(suelo) <- c('clay','sand','silt','awc')

writeRaster(suelo,'/mnt/data_procesada/papers/frickius_SDM/suelo.tif')

# suelo <- rast('/mnt/data_procesada/papers/frickius_SDM/suelo.tif')

# 5. NDVI ----

files <- dir_ls('/home/francisco/Descargas/NDVI.MOD13A3.061')

ind <- map(1:12,\(i) seq(i,length(files),12))

l <- list()
for( i in seq_along(ind)){
  r <- rast(files[ind[[i]]])
  r_mean <- mean(r,na.rm  =TRUE)
  r_cov <- app(r,\(x) sd(x,na.rm  =TRUE) / mean(x,na.rm = TRUE),cores = 80)
  cli::cli_alert_success(month.name[i])
  l[[i]] <- c(r_mean,r_cov)
  }

ndvi_met <- rast(l)
names(ndvi_met) <- sapply(month.abb,\(x) paste0(x,c('_mean','_cov'))) |> as.character()
ndvi_met <- project(ndvi_met,bio)
writeRaster(ndvi_met,'~/Descargas/frickius_SDM/ndvi_mettricas.tif',overwrite = TRUE)

# 6. Juntar todos los predictores en un raster stack ----

lcpers <- crop(lcpers,preds_lndsc_metrics)
lcpers_rs <- project(lcpers,crs(bio),method = 'near')
lcpers_resam <- resample(lcpers_rs,bio,method = 'near')

preds_lndsc_metrics_rs <- project(preds_lndsc_metrics,crs(bio),method = 'near')
preds_lndsc_metrics_resam <- resample(preds_lndsc_metrics_rs,
                                      bio)

preds_all <- c(vars_dem,bio,lcpers_resam,preds_lndsc_metrics_resam,suelo,ndvi_met_s)
names_new <- str_remove(names(preds_all),'wc2.1_30s_')
names_new[23] <- 'landc_pers'
names(preds_all) <- names_new           

writeRaster(preds_all,'/mnt/data_procesada/papers/frickius_SDM/todos_los_predictores.tif',overwrite = TRUE)
