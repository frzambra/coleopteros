library(terra)
library(sf)
library(tidyverse)

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

lcpers <- rast('/media/francisco/data_procesada/papers/frickius_SDM/IGBP80_reclassified.tif')

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
            '/media/francisco/data_procesada/papers/frickius_SDM/metricas_ldscp_lc_pers_2001-2023.tif',overwrite  =TRUE)

# 5. Juntar todos los predictores en un raster stack

lcpers <- crop(lcpers,preds_lndsc_metrics)
lcpers_rs <- project(lcpers,crs(bio),method = 'near')
lcpers_resam <- resample(lcpers_rs,bio,method = 'near')

preds_lndsc_metrics_rs <- project(preds_lndsc_metrics,crs(bio),method = 'near')
preds_lndsc_metrics_resam <- resample(preds_lndsc_metrics_rs,
                                      bio)

preds_all <- c(vars_dem,bio,lcpers_resam,preds_lndsc_metrics_resam)
names_new <- str_remove(names(preds_all),'wc2.1_30s_')
names_new[23] <- 'landc_pers'
names(preds_all) <- names_new           

writeRaster(preds_all,'/media/francisco/data_procesada/papers/frickius_SDM/todos_los_predictores.tif',overwrite = TRUE)
