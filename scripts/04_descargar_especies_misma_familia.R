library(tidyverse)
library(rgbif)
library(sf)

especies <- c('Bolborhinum geotrupoides',
              'Bolborhinum laesicolle',
              'Bolborhinum nasutum',
              'Bolborhinum shajovskoyi',
              'Bolborhinum tricorne',
              'Bolborhinum trilobulicorne',
              'Bolborhinum tubericeps')

d <- map_df(especies,\(name) name_backbone(name))

keys <- d$usageKey

map(keys[7],\(k) occ_download(pred("taxonKey",k)))

ids <- c('0000645-250123221155621',
         '0000646-250123221155621',
         '0000647-250123221155621',
         '0000636-250123221155621',
         '0000637-250123221155621',
         '0000638-250123221155621',
         '0000666-250123221155621')

data <- ids |> 
  map_df(\(id){
    occ_download_get(id,path = 'data/raw/gbif') |> 
      occ_download_import() |> 
      select(occurrenceStatus,decimalLongitude,decimalLatitude) |> 
      rename(ocurrencia = occurrenceStatus,
             longitud = decimalLongitude,
             latitud = decimalLatitude)
  })

data_sf <- data |>
  drop_na(longitud,latitud) |> 
  st_as_sf(coords = c('longitud','latitud'),crs = 4326)

write_rds(data_sf,'data/processed/data_sf_especies_misma_familia.rds')
