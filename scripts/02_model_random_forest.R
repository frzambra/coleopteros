library(tidyverse)
library(tidymodels)
library(sf)
library(tmap)
library(fs)
library(terra)
library(rnaturalearth)

## leer los datos
data <-  readxl::read_xlsx('data/raw/Frickius_iNaturalist_BahiaExploradores.xlsx',sheet=1) |> 
  st_as_sf(coords =c('longitude','latitude'),crs=4326) 

## agregar coordenadas
data <- data |> cbind(lon=st_coordinates(data)[,1])

#extensión de Chile
chl <- ne_countries(country = 'Chile',scale = 'medium',returnclass = 'sf')

#pseudo ausencia de la especie
sa <- st_as_sfc(st_bbox(data)) |> st_sample(100) 

# extensión espacial que se considerará para el modelo
bb <- st_bbox(c(xmin=-77,ymin=-56,xmax=-63,ymax=-37))

#se agregan los puntos de seudo-ausencia de la especie
data4model <- c(data$geometry,sa) |> st_as_sf()

# 1= presencia de la especie, 0 = seudo-ausencia de la especie
data4model$pres <- NA
data4model$pres[1:49] <- 1
data4model$pres[50:149] <- 0

#predictores rasters humedad de suelo (sm), temperatura (temp) y precipitación (temp)
dir_sm <- '/mnt/md0/raster_procesada/ERA5-Land_tiff/clima/volumetric_soil_water/monthly'
dir_temp <-  '/mnt/md0/raster_procesada/ERA5-Land_tiff/clima/2m_mean_temperature/monthly'
dir_pre <-  '/mnt/md0/raster_procesada/ERA5-Land_tiff/clima/total_precipitation/monthly'

sm <- rast(dir_ls(dir_sm,regexp = '(2017|2018|2019|2020|2021|2022).*tif$'))
temp <- rast(dir_ls(dir_temp,regexp = '(2017|2018|2019|2020|2021|2022).*tif$'))
pre <- rast(dir_ls(dir_pre,regexp = '(2017|2018|2019|2020|2021|2022).*tif$'))

#indices para calcular los promedios mensuales entre 2017-2022
ind <- rep(1:12,6)

#predictores agregados mensuales
sm_z <- crop(sm,bb)
csm_z <- tapp(sm_z,ind,sum)
names(csm_z) <- paste0('HS_',month.abb)

pre_z <- crop(pre,bb)*1000
pre_z <- tapp(pre_z,ind,sum)
names(pre_z) <- paste0('Pre_',month.abb)
  
temp_z <- crop(temp,bb)-273.15
temp_z <- tapp(temp_z,ind,mean)
names(temp_z) <- paste0('Temp_',month.abb)

#NDVI índice de vegetación
dir_ndvi <- '/mnt/md0/raster_procesada/MODIS/NDVI.MOD13A3.061'
files_ndvi <- dir_ls(dir_ndvi,regexp = 'tif$')
ind <- sapply(1:12,\(i) seq(i,284,12))
res <- lapply(ind,\(i){
  rast(files_ndvi[i]) |> app(mean,na.rm=TRUE)
})

ndvi_mes <- rast(res)
ndvi_mes_r <- project(ndvi_mes,temp_z)
ndvi_mes_r <- crop(ndvi_mes_r,bb)
names(ndvi_mes_r) <- paste0('ndvi_',month.abb)

#resampleo para que los predictores tengan la misma resolución espacial
sm_z <-  resample(sm_z,ndvi_mes_r[[1]])
temp_z <- resample(temp_z,ndvi_mes_r[[1]])
pre_z <- resample(pre_z,ndvi_mes_r[[1]])

#elevación
library(geodata)
#obtener elevación a 30" de resolución espacial
dem <- elevation_30s('chile', path=tempdir())
dem <- crop(dem,bb)
dem <- resample(dem,ndvi_mes_r[[1]])
names(dem) <- 'dem'

#unir todos los predictores
preds <- c(ndvi_mes_r,pre_z,temp_z,dem)

data4model <- cbind(data4model,extract(preds,data4model))

library(tidyverse)
library(tidymodels)

#Preparar los datos para la modelación
data4modelf <- data4model |> 
  st_drop_geometry() |> 
  select(-ID) |> 
  mutate(across(-pres,scale)) |> 
  mutate(pres = factor(pres)) |> 
  drop_na()

set.seed(123)

#dividir set de datos en entrenamiento y test
fric_split <- initial_split(data4modelf,strata = pres)

fric_split_train <- training(fric_split)
fric_test <- testing(fric_split)
fric_train <- training(fric_split)

#modelo random forest 
rf_spec <- rand_forest(trees = 1000, mode = "classification") |> 
  set_args(importance = 'impurity')
rf_wflow <- workflow(pres ~ ., rf_spec)
rf_fit <- fit(rf_wflow, fric_train)

# modelo naibe bayes
nb_spec <- naive_Bayes(mode = "classification")
nb_wflow <- workflow(pres ~ ., nb_spec)
nb_fit <- fit(nb_wflow, fric_train)

augment(rf_fit, new_data = fric_train) %>%
  conf_mat(truth = pres, estimate = .pred_class)

augment(rf_fit, new_data = fric_train) %>%
  conf_mat(truth = pres, estimate = .pred_class) %>%
  autoplot(type = "heatmap")

augment(rf_fit, new_data = fric_test) %>%
  accuracy(truth = pres, estimate = .pred_class)


preds_tbl <- values(preds) |> 
  as_tibble() |> 
  mutate(across(everything(),\(x) scale(x)[,1]))

preds_tbl |> 
  rowid_to_column() |> 
  filter(if_all(everything(),\(x) !is.na(x))) |> 
  pull(rowid) -> rid

preds_fric_rf <- predict(rf_fit,preds_tbl[rid,])
preds_fric_nb <- predict(nb_fit,preds_tbl[rid,])

preds_final_rf <- tibble(preds = rep(NA,nrow(preds_tbl)))
preds_final_nb <- tibble(preds = rep(NA,nrow(preds_tbl)))

preds_final_rf[rid,] <- preds_fric_rf$.pred_class
preds_final_nb[rid,] <- preds_fric_nb$.pred_class

res_rf <- preds[[1]]
res_nb <- preds[[1]]
values(res_rf) <- NA 
values(res_nb) <- NA 

values(res_rf) <- preds_final_rf$preds
values(res_nb) <- preds_final_nb$preds
plot(res_rf)
plot(res_nb)
#
#
library(vip)
rf_fit |> 
extract_fit_parsnip() |> 
vip(geom = "point") + 
  labs(title = "Random forest variable importance") 

nb_fit |> 
  extract_fit_parsnip() |> 
  vip(geom = "point") + 
  labs(title = "Random forest variable importance") 

# Model Evaluation

set.seed(345)
folds <- vfold_cv(fric_split_train, v = 5)
folds

rf_wf <- 
  workflow() |> 
  add_model(rf_spec) |> 
  add_formula(pres ~ .)

nb_wf <- 
  workflow() |> 
  add_model(nb_spec) |> 
  add_formula(pres ~ .)

set.seed(456)
rf_fit_rs <- 
  rf_wf |> 
  fit_resamples(folds)

nb_fit_rs <- 
  nb_wf |> 
  fit_resamples(folds)

rf_fit_rs |> 
  unnest(c(.metrics))

nb_fit_rs |> 
  unnest(c(.metrics))

collect_metrics(rf_fit_rs)

rf_testing_pred <- 
  predict(rf_fit, fric_test) |> 
  bind_cols(predict(rf_fit, fric_test, type = "prob")) %>% 
  bind_cols(fric_test %>% dplyr::select(pres))

nb_testing_pred <- 
  predict(nb_fit, fric_test) |> 
  bind_cols(predict(nb_fit, fric_test, type = "prob")) %>% 
  bind_cols(fric_test %>% dplyr::select(pres))

rf_testing_pred |>                    # test set predictions
  #mutate(across(everything(),as.numeric)) |> 
  roc_auc(truth = pres, .pred_0)

nb_testing_pred |>                    # test set predictions
  #mutate(across(everything(),as.numeric)) |> 
  roc_auc(truth = pres, .pred_0)

rf_testing_pred %>%                   # test set predictions
  accuracy(truth = pres, .pred_class)

nb_testing_pred %>%                   # test set predictions
  accuracy(truth = pres, .pred_class)
