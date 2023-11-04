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

# crear sumatoria humedad de suelo
zone <- st_bbox(data) |> st_as_sfc() |> st_as_sf() |> st_buffer(10000)

ind <- lapply(1:6,\(x) rep(x,12)) |> unlist()

sm_z <- crop(sm,zone)
csm_z <- tapp(sm_z,ind,sum)
resam <- sm_z
csm_z_res <- resample(csm_z,disagg(sm_z,20))

#mapa de humedad acumulada anual con la ubicación de los puntos

map_hs <- tm_shape(mean(csm_z_res)) + 
  tm_raster(style = 'cont',title ='Annual Soil Moisture (mm)',palette = 'Blues') + 
  tm_shape(data) + 
  tm_dots(col = 'Presence',style = 'cat',labels = c('No','Yes'),palette = c('blue','red')) +
  #tm_graticules() +
  tm_compass(position = c('right','top')) +
  tm_scale_bar() +
  tm_layout(legend.outside = TRUE)
tmap_save(map_hs,'output/figs/mapa_humedad_suelo_anual.png',scale = 1)

# crear sumatoria precipitación

pre_z <- crop(pre,zone)*1000
pre_z <- tapp(pre_z,ind,sum)
resam <- pre_z
pre_z_res <- resample(pre_z,disagg(sm_z,20))

#mapa de humedad acumulada anual con la ubicación de los puntos

map_pre <- tm_shape(mean(pre_z_res)) + 
  tm_raster(style = 'cont',title ='Annual Precipitation (mm)',palette = 'Blues') + 
  tm_shape(data) + 
  tm_dots(col = 'Presence',style = 'cat',labels = c('No','Yes'),palette = c('blue','red')) +
  #tm_graticules() +
  tm_compass(position = c('right','top')) +
  tm_scale_bar() +
  tm_layout(legend.outside = TRUE)
tmap_save(map_pre,'output/figs/mapa_precipitacion_anual.png',scale = 1)

## Mapa temperatura promedio
temp_z <- crop(temp,zone)-273.15
temp_z <- tapp(temp_z,ind,mean)
resam <- temp_z
temp_z_res <- resample(temp_z,disagg(sm_z,20))

#mapa de humedad acumulada anual con la ubicación de los puntos

map_temp <- tm_shape(mean(temp_z_res)) + 
  tm_raster(style = 'cont',title ='Mean Annual Temperature (°C)',palette = 'Reds',alpha = .6) + 
  tm_shape(data) + 
  tm_dots(col = 'Presence',style = 'cat',labels = c('No','Yes'),palette = c('blue','red')) +
  #tm_graticules() +
  tm_compass(position = c('right','top')) +
  tm_scale_bar() +
  tm_layout(legend.outside = TRUE)
tmap_save(map_temp,'output/figs/mapa_temperatura_anual.png',scale = 1)

###
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

map_sm <- df_sm |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  group_by(Sector,geometry) |> 
  summarize(med = median(value,na.rm=TRUE)) |> 
  st_as_sf() |> 
  tm_shape() + 
  tm_dots(col="med",style='jenks')
tmap_save(map_sm,'output/figs/map_sm_median_2017-2023.html')

ggplot(aes(lon,med,color=Sector))+ 
  geom_point()
  
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

map_pre <- df_pre |> 
  pivot_longer(2:73) |> 
  mutate(dates = ymd(name)) |> 
  select(-name) |> 
  group_by(Sector,geometry) |> 
  summarize(med = median(value,na.rm=TRUE)) |> 
  st_as_sf() |> 
  tm_shape() + 
  tm_dots(col="med",style='jenks')
tmap_save(map_pre,'output/figs/map_pre_median_2017-2023.html')

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
