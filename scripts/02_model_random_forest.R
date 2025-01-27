library(tidyverse)
library(tidymodels)
library(sf)
library(tmap)
library(fs)
library(terra)
library(rnaturalearth)

## leer los datos
data <-  read_csv('data/processed/Datos-consolidados_Fvariolosus_20241013.csv') |> 
  select(1:7) |> 
  st_as_sf(coords =c('decimalLongitude','decimalLatitude'),crs=4326) 

data <- data |> cbind(lon=st_coordinates(data)[,1])


# cargar predictores
preds <- rast('data/raw/rasters/predictores.tif')

#pseudo ausencia de la especie
set.seed(876)
sa <- st_as_sfc(st_bbox(data)) |> st_sample(164) 

# extensión espacial que se considerará para el modelo
bb <- st_bbox(preds)

#se agregan los puntos de seudo-ausencia de la especie
data4model <- c(data$geometry,sa) |> st_as_sf()

# 1= presencia de la especie, 0 = seudo-ausencia de la especie
data4model$pres <- NA
data4model$pres[1:164] <- 1
data4model$pres[165:328] <- 0

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

preds_fric_rf <- predict(rf_fit,preds_tbl[rid,],type = 'prob')
preds_fric_nb <- predict(nb_fit,preds_tbl[rid,])

preds_final_rf <- tibble(preds = rep(NA,nrow(preds_tbl)))
preds_final_nb <- tibble(preds = rep(NA,nrow(preds_tbl)))

preds_final_rf[rid,] <- preds_fric_rf$.pred_0
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
