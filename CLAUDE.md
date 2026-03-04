# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Species Distribution Modeling (SDM) for *Frickius variolosus* (a beetle) in Chile and Argentina. The pipeline generates current and future (2061–2080, SSP585 scenario) distribution predictions using an ensemble of GLM, Random Forest, Gradient Boosting, and MaxEnt models.

## Running the Pipeline

Scripts must run sequentially in order. In R:

```r
source("scripts/00_preparar_predictores_raster.R")
source("scripts/01_analisis_preliminar.R")
source("scripts/02_model_random_forest.R")
source("scripts/03_preparar_area_estudio.R")
source("scripts/04_descargar_especies_misma_familia.R")
source("scripts/05_preparar_ausencia-presencia.R")
source("scripts/06_preparar_predictores_raster.R")
source("scripts/07_modelado_con_tidydsm.R")
source("scripts/08_preparar_predictores_proyecciones.R")
source("scripts/09_mapas_predicciones.R")
```

Render the Quarto report:
```r
quarto::quarto_render("reporte/01_distribucion_frickius_modelos_rf_nb.qmd")
```

## Architecture

### Data Flow

```
GBIF occurrences + Climate rasters (WorldClim, CMIP6, TerraClimate)
+ Soil data (SoilGRID) + Land cover (MapBiomas) + Elevation (DEM)
    ↓
[00, 06, 08] Prepare predictors (current & future)
    ↓
[03] Define study area (Chile/Argentina masks)
    ↓
[05] Thin observations + generate pseudo-absences (tidysdm)
    ↓
[07] Fit ensemble SDM (tidysdm/tidymodels) + DALEX explanations
    ↓
[09] Generate comparison maps (current vs. 2061-2080)
```

### Key Files

- **scripts/07_modelado_con_tidydsm.R** — Core modeling: ensemble fitting, cross-validation, feature importance, predictions
- **scripts/06_preparar_predictores_raster.R** — Feature engineering: bioclimatic variables, soil, NDVI, landscape metrics
- **scripts/08_preparar_predictores_proyecciones.R** — Future climate predictors from CMIP6 AWI-CM-1-1-MR
- **scripts/09_mapas_predicciones.R** — Final maps with OpenStreetMap basemap
- **reporte/01_distribucion_frickius_modelos_rf_nb.qmd** — Quarto report (Spanish)

### External Data Paths

Scripts reference data on shared storage:
- `/mnt/data_procesada/papers/frickius_SDM/` — Processed predictors and model outputs
- `/mnt/data_raw/CMIP6/` — Future climate rasters

Local processed outputs go to `data/processed/`. Raw data (`data/raw/`) is git-ignored.

### Core Libraries

| Purpose | Packages |
|---------|---------|
| SDM workflow | `tidysdm`, `tidymodels` |
| Geospatial | `terra`, `sf`, `tidyterra` |
| Climate/species data | `geodata`, `climateR`, `rgbif` |
| Model interpretation | `DALEX`, `vip` |
| Landscape metrics | `landscapemetrics` |
| Visualization | `ggplot2`, `tmap`, `rnaturalearth` |

## Code Conventions

- All comments and variable names are in Spanish
- 2-space indentation (set in `.Rprofile` via RStudio project)
- Script 02 is a quick exploratory RF/NB — the production model lives in script 07
- Model objects and prediction rasters are saved as `.rds` and `.tif` in `data/processed/`
