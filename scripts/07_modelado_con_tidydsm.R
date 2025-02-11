library(terra)
library(tidyverse)

# 1.- Cargar datos ----
## predictores raster
preds <- rast('/media/francisco/data_procesada/papers/frickius_SDM/todos_los_predictores.tif')
data_preaus <- read_rds('data/processed/datos_ausencia-presencia.rds')

## datos de presencia-ausencia

data_model <- data_preaus |> 
  bind_cols(extract(preds,data_preaus)) |> 
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
  frick_models %>%
  workflow_map("tune_grid",
               resamples = frick_cv, grid = 3,
               metrics = sdm_metric_set(), verbose = TRUE
  )

autoplot(frick_models)

frick_ensemble <- simple_ensemble() |> 
  add_member(frick_models,metric = 'boyce_cont')

autoplot(frick_ensemble)

frick_ensemble |> collect_metrics()

explainer_frick_ensemble <- explain_tidysdm(frick_ensemble)

# Explicación del modelo
library(DALEX)

vip_ensemble <- model_parts(explainer = explainer_frick_ensemble)

plot <- plot(vip_ensemble)
ggsave(plot= plot,'output/figs/feature_importance_ensamble.png',
       bg = 'white',scale=2)

model_profile(explainer_frick_ensemble,N=500,variable = "lsm_p_ncore") |> 
  plot()

prediction <- predict_raster(frick_ensemble,preds)
plot(prediction)

map <- tm_shape(prediction) + 
  tm_raster(col.scale = tm_scale_continuous(values = "brewer.rd_yl_gn",
                                            midpoint = NA),
            col.legend = tm_legend(
              title = 'Probabilidad'
            ))
tmap_save(map,'output/html/mapa_sdm_frickius.html')
