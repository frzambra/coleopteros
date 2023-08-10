library(tidyverse)
library(sf)
library(tmap)
library(fs)
library(terra)

data <-  readxl::read_xlsx('data/raw/Frickius_iNaturalist_BahiaExploradores.xlsx',sheet=2) |> 
  st_as_sf(coords =c('Lon','Lat'),crs=4326) 

data <- data |> cbind(lon=st_coordinates(data)[,1])

dir_sm <- '/mnt/md0/raster_procesada/ERA5-Land_tiff/clima/volumetric_soil_water/monthly'
dir_temp <-  '/mnt/md0/raster_procesada/ERA5-Land_tiff/clima/2m_mean_temperature/monthly'
dir_pre <-  '/mnt/md0/raster_procesada/ERA5-Land_tiff/clima/total_precipitation/monthly'

sm <- rast(dir_ls(dir_sm,regexp = '(2017|2018|2019|2020|2021|2022).*tif$'))
temp <- rast(dir_ls(dir_temp,regexp = '(2017|2018|2019|2020|2021|2022).*tif$'))
pre <- rast(dir_ls(dir_pre,regexp = '(2017|2018|2019|2020|2021|2022).*tif$'))

df_sm <- extract(sm,data) |> cbind(data)
names(df_sm)[2:73] <-  str_extract(names(df_sm)[2:73],'[0-9]{4}-[0-9]{2}-[0-9]{2}')
df_sm |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  ggplot(aes(dates,value,color=Sector)) +
  geom_point() + 
  geom_line() +
  scale_color_viridis_d()+
  theme_bw()
ggsave('output/figs/variacion_sm_coleopteros.png',scale=2)

df_sm |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  ggplot(aes(Sector,value,fill=lon)) +
  geom_violin() + 
  scale_fill_viridis_c()+
  theme_bw() +
  theme(axis.text.x = element_text(angle=90,hjust=1))
ggsave('output/figs/boxplot_sm_coleopteros.png',scale=2)

df_temp <- extract(temp,data) |> cbind(data)
names(df_temp)[2:73] <-  str_extract(names(df_temp)[2:73],'[0-9]{4}-[0-9]{2}-[0-9]{2}')
df_temp |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  ggplot(aes(dates,value,color=Sector)) +
  geom_point() + 
  geom_line() +
  scale_color_viridis_d()+
  theme_bw()
ggsave('output/figs/variacion_temp_coleopteros.png',scale=2)

df_temp |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  ggplot(aes(Sector,value,fill=lon)) +
  geom_violin() + 
  #geom_jitter() +
  scale_fill_viridis_c()+
  theme_bw() +
  theme(axis.text.x = element_text(angle=90,hjust=1))
ggsave('output/figs/boxplot_temp_coleopteros.png',scale=2)


df_pre <- extract(pre,data) |> cbind(data)
names(df_pre)[2:73] <-  str_extract(names(df_pre)[2:73],'[0-9]{4}-[0-9]{2}-[0-9]{2}')
df_pre |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  ggplot(aes(dates,value,color=Sector)) +
  geom_point() + 
  geom_line() +
  scale_color_viridis_d()+
  theme_bw()
ggsave('output/figs/variacion_pre_coleopteros.png',scale=2)

df_pre |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  ggplot(aes(Sector,value,fill=lon)) +
  geom_violin() + 
  #geom_jitter() +
  scale_fill_viridis_c()+
  theme_bw() +
  theme(axis.text.x = element_text(angle=90,hjust=1))
ggsave('output/figs/boxplot_pre_coleopteros.png',scale=2)

tmap_mode('view')
tm_shape(data) + 
  tm_markers()

write_sf(data,'data/processed/datos_frickius.gpkg')
