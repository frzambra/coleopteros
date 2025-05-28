library(terra)
library(tidyverse)
library(tidysdm)

# 1.- Cargar datos ----
## predictores raster
preds <- rast('/mnt/data_procesada/papers/frickius_SDM/todos_los_predictores.tif')
data_preaus <- read_rds('data/processed/datos_ausencia-presencia.rds')

## datos de presencia-ausencia

data_model <- data_preaus |> 
  bind_cols(terra::extract(preds,data_preaus)) |> 
  select(-ID) |> 
  drop_na()


library(tidymodels)

frick_rec <- recipe(data_model,class~.)

data_model |> check_sdm_presence(class)

frick_models <-
  # create the workflow_set
  workflow_set(
    preproc = list(default = frick_rec),
    models = list(
      # the standard glm specs
      glm = sdm_spec_glm(),
      # rf specs with tuning
      rf = sdm_spec_rf(),
      # boosted tree model (gbm) specs with tuning
      gbm = sdm_spec_boost_tree(),
      # maxent specs with tuning
      maxent = sdm_spec_maxent()
    ),
    # make all combinations of preproc and models,
    cross = TRUE
  ) |> 
  # tweak controls to store information needed later to create the ensemble
  option_add(control = control_ensemble_grid())

set.seed(100)
frick_cv <- spatial_block_cv(data = data_model, v = 3, n = 5)
autoplot(frick_cv)

set.seed(1234567)
frick_models <-
  frick_models |> 
  workflow_map("tune_grid",
               resamples = frick_cv, grid = 3,
               metrics = sdm_metric_set(), verbose = TRUE
  )

autoplot(frick_models)

frick_ensemble <- simple_ensemble() |> 
  add_member(frick_models,metric = 'boyce_cont')

#Guardar modelo en el disco
#
write_rds(frick_ensemble,'data/processed/modelo_ensamblado_frickius.rds')
#frick_ensemble <- read_rds('data/processed/modelo_ensamblado_frickius.rds')

autoplot(frick_ensemble) +
  theme_bw()

frick_ensemble |> collect_metrics()

explainer_frick_ensemble <- explain_tidysdm(frick_ensemble)

# Explicación del modelo
library(DALEX)
set.seed(1976)
vip_ensemble <- model_parts(explainer = explainer_frick_ensemble)

vip_ensemble$label <- ''

plot <- plot(vip_ensemble,max_vars = 15) +
  labs(title = NULL,subtitle = NULL,caption = NULL,tag = NULL) 

ggsave(plot= plot,'output/figs/feature_importance_ensamble.png',
       bg = 'white',scale=1.5) 

model_profile(explainer_frick_ensemble,N=500,variable = "clay") |> 
  plot()

#predecir en los predictores con los datos climaticos actuales
prediction <- predict_raster(frick_ensemble,preds)
prediction <- trim(prediction)

#predecir considerando las proyecciones 2061-2080
preds_proj <- rast('/mnt/data_procesada/papers/frickius_SDM/todos_los_predictores_proyecciones.tif')
preds_proj[is.infinite(preds_proj)] <- NA

names(preds_proj)[4:22] <- paste0('bio_',1:19)
prediction_proj <- predict_raster(frick_ensemble,preds_proj)
prediction_proj <- crop(prediction_proj,ext(prediction))

preds_res <- c(prediction,prediction_proj,prediction-prediction_proj)
names(preds_res) <- c('Actual','Proy. 2061-2080','Diferencia')
writeRaster(preds_res,'data/processed/raster_predicciones_1970-2000_2061-2080.tif',overwrite = TRUE)

