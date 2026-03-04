# Propuestas de mejora: SDM para *Frickius variolosus*

**Fecha:** 2026-03-04
**Scripts involucrados:** `05_preparar_ausencia-presencia.R`, `06_preparar_predictores_raster.R`, `07_modelado_con_tidydsm.R`

---

## Resumen ejecutivo

Se identificaron 7 oportunidades de mejora en el pipeline actual, organizadas por prioridad. Las más críticas afectan la validez de la validación cruzada (CV se corre sobre datos sin filtrar) y la resolución del ajuste de hiperparámetros (`grid = 3` es insuficiente). Las demás mejoran la robustez ecológica y la interpretabilidad de resultados.

---

## Prioridad Alta

### 1. Validación cruzada sobre datos incorrectos

**Archivo:** `scripts/07_modelado_con_tidydsm.R`, línea 65
**Problema:** `spatial_block_cv()` se aplica a `data_model` (con todas las variables originales), pero el modelo se entrena con `data_model_filt` (variables sin colinealidad). El CV evalúa una distribución de predictores distinta a la que usa el modelo.

**Código actual:**
```r
set.seed(100)
frick_cv <- spatial_block_cv(data = data_model, v = 3, repeats = 5)
```

**Código propuesto:**
```r
set.seed(100)
frick_cv <- spatial_block_cv(
  data    = data_model_filt,  # datos con variables ya filtradas
  v       = 5,                # 5 folds mejora la estimación del error
  repeats = 3
)
autoplot(frick_cv)
```

---

### 2. Grilla de hiperparámetros demasiado pequeña

**Archivo:** `scripts/07_modelado_con_tidydsm.R`, líneas 69–74
**Problema:** `grid = 3` solo prueba 3 combinaciones de hiperparámetros por modelo. Para RF y GBM —que tienen al menos 3 parámetros a tunear— esto es insuficiente y produce modelos subóptimos.

**Código actual:**
```r
frick_models <- frick_models |>
  workflow_map("tune_grid",
               resamples = frick_cv, grid = 3,
               metrics = sdm_metric_set(), verbose = TRUE)
```

**Código propuesto (opción A — grilla mayor):**
```r
frick_models <- frick_models |>
  workflow_map(
    "tune_grid",
    resamples = frick_cv,
    grid      = 20,               # mínimo recomendado
    metrics   = sdm_metric_set(),
    verbose   = TRUE
  )
```

**Código propuesto (opción B — búsqueda bayesiana, más eficiente):**
```r
frick_models <- frick_models |>
  workflow_map(
    "tune_bayes",
    resamples  = frick_cv,
    iter       = 25,              # iteraciones de optimización bayesiana
    metrics    = sdm_metric_set(),
    verbose    = TRUE
  )
```

> La opción B encuentra mejores hiperparámetros con menos evaluaciones que una grilla regular.

---

## Prioridad Media

### 3. Método de selección de variables: `cor_caret` → VIF

**Archivo:** `scripts/07_modelado_con_tidydsm.R`, líneas 31–33
**Problema:** `cor_caret` detecta correlaciones pairwise pero no multicolinealidad emergente (cuando varias variables se combinan para predecir otra). VIF es más riguroso para conjuntos de predictores grandes como el actual (~80 variables entre bioclim, suelo, NDVI y métricas de paisaje).

**Código actual:**
```r
vars_uncor <- filter_collinear(data_model,
                               cutoff = 0.7,
                               method = "cor_caret")
```

**Código propuesto:**
```r
set.seed(42)  # filter_collinear puede tener componentes aleatorios en desempates
vars_uncor <- filter_collinear(
  data_model,
  cutoff    = 10,        # umbral VIF estándar; usar 5 para ser más restrictivo
  method    = "vif",
  to_keep   = "class"   # excluir la variable respuesta del cálculo
)
```

---

### 4. Signo invertido en la diferencia de predicciones

**Archivo:** `scripts/07_modelado_con_tidydsm.R`, línea 124
**Problema:** La fórmula `prediction - prediction_proj` produce valores positivos donde el hábitat se **pierde** y negativos donde se **gana**. Esto es ecológicamente contraintuitivo y puede confundir la interpretación de los mapas.

**Código actual:**
```r
preds_res <- c(prediction, prediction_proj, prediction - prediction_proj)
names(preds_res) <- c('Actual', 'Proy. 2061-2080', 'Diferencia')
```

**Código propuesto:**
```r
# Positivo = ganancia futura de hábitat; negativo = pérdida
preds_res <- c(prediction, prediction_proj, prediction_proj - prediction)
names(preds_res) <- c('Actual', 'Proy. 2061-2080', 'Diferencia')
```

---

### 5. Buffer de pseudo-ausencias demasiado pequeño

**Archivo:** `scripts/05_preparar_ausencia-presencia.R`, líneas 23–26
**Problema:** Con un buffer de exclusión de 1 km y predictores de resolución ~1 km (WorldClim), las pseudo-ausencias pueden caer en píxeles ambientalmente casi idénticos a las presencias. Esto disminuye el contraste ambiental y sesga la calibración del modelo. Además, `n = nrow(data_sf)` usa el conteo pre-rarefacción; debería usar `nrow(data_pres)` post-rarefacción.

**Código actual:**
```r
data_full <- sample_pseudoabs(data_pres,
                              area_estudio_raster,
                              n = nrow(data_sf)*3,
                              method = c('dist_min',1000))
```

**Código propuesto:**
```r
data_full <- sample_pseudoabs(
  data_pres,
  area_estudio_raster,
  n      = nrow(data_pres) * 5,   # base post-rarefacción; ratio 5:1 mejora calibración
  method = c('dist_min', 5000)    # 5 km excluye vecindad ambiental inmediata
)
```

---

## Prioridad Baja

### 6. Verificación de autocorrelación espacial en residuos

**Archivo:** nuevo bloque al final de `scripts/07_modelado_con_tidydsm.R`
**Problema:** No existe ninguna verificación de que el CV espacial haya controlado efectivamente la autocorrelación. Si el test de Moran resulta significativo, indica que los bloques son demasiado pequeños y las estimaciones de rendimiento están infladas.

**Código propuesto:**
```r
library(spdep)

# Predicciones del ensemble sobre datos de entrenamiento
preds_train <- predict(frick_ensemble, data_model_filt, type = "prob")$.pred_presence
residuos    <- as.numeric(data_model_filt$class == "presence") - preds_train

# Test de Moran con 8 vecinos más cercanos
coords <- st_coordinates(data_model_filt)
nb     <- knn2nb(knearneigh(coords, k = 8))
lw     <- nb2listw(nb, style = "W")
moran.test(residuos, lw)
```

> Si `p-value < 0.05`, aumentar `cellsize` en `spatial_block_cv()` (cambio 1).

---

### 7. Indexación frágil de capas en predictores futuros

**Archivo:** `scripts/07_modelado_con_tidydsm.R`, línea 120
**Problema:** `names(preds_proj)[4:22]` asume que las variables bioclimáticas siempre ocupan exactamente las posiciones 4 a 22. Si el raster de proyecciones cambia (nuevo escenario, diferente orden), el renombramiento silenciosamente asigna nombres incorrectos.

**Código actual:**
```r
names(preds_proj)[4:22] <- paste0('bio_', 1:19)
```

**Código propuesto:**
```r
idx_bio <- grep("^bio", names(preds_proj))
stopifnot(length(idx_bio) == 19)                    # falla si el raster no tiene 19 bio vars
names(preds_proj)[idx_bio] <- paste0('bio_', seq_along(idx_bio))
```

---

## Tabla resumen

| # | Prioridad | Descripción | Archivo | Línea |
|---|-----------|-------------|---------|-------|
| 1 | **Alta** | CV sobre `data_model_filt`, no `data_model` | 07 | 65 |
| 2 | **Alta** | `grid = 3` → `grid = 20` o `tune_bayes` | 07 | 72 |
| 3 | **Media** | `filter_collinear`: `cor_caret` → `vif` | 07 | 31 |
| 4 | **Media** | Signo de diferencia invertido | 07 | 124 |
| 5 | **Media** | Buffer pseudo-ausencias: 1 km → 5 km | 05 | 23 |
| 6 | **Baja** | Moran's I sobre residuos del ensemble | 07 | nuevo |
| 7 | **Baja** | Indexación robusta de bio vars futuras | 07 | 120 |
