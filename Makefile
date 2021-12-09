##############################################
# Tools
PHYGHTMAP=phyghtmap
OSMCONVERT=osmconvert64.exe
SPLITTER=c:\Apps\splitter\splitter.jar
MKGMAP=c:\Apps\mkgmap-4819\mkgmap.jar
MKNSIS="c:\Program Files (x86)\NSIS\Bin\makensis.exe"
WGET=wget
COPY=copy /b
MOVE=ren
DEL=del

##############################################
# External data sources
GEOFABRIK_URL=http://download.geofabrik.de/europe/
TJEL_URL=https://data2.openstreetmap.hu/
TJEL_NAME=vjel.osm

##############################################
# Data cache locations
DATASET_DIR=c:\Dataset\map
HGT_DIR=$(DATASET_DIR)\hgt
DEM_DIR=$(HGT_DIR)\SRTM1v3.0
OSM_CACHE_DIR=$(DATASET_DIR)\osm
CONTOUR_DIR=$(DATASET_DIR)\contour
TJEL_CACHE_DIR=$(DATASET_DIR)\jelek


##############################################
# Map configuration

OSM_COUNTRIES_CE=slovakia hungary
OSM_COUNTRIES_HU=hungary

BOUNDARY_POLYGON_CE=$(CONFIG_DIR)\slovakia.poly
BOUNDARY_POLYGON_HU=$(CONFIG_DIR)\hungary.poly



##############################################
# Builder configuration
CONFIG_DIR=config
STYLES_DIR=styles


##############################################
# Contour Lines

CONTOUR_START_ID=100000000000
COUNTOUR_BBOX_CE=15.7331:45.5831:23.2258:49.7243
#COUNTOUR_BBOX_HU=15.9308898449:45.6368622762:23.1598937511:48.6979999426 --start-node-id=750000000000

CONTOUR_FILE_PFX=$(CONTOUR_DIR)\contour-

CONTOUR_CE=contour-ce.o5m
CONTOUR_HU=contour-hu.o5m


##############################################
# Dataset Preparation

OHM_INP_OSM_CE := $(foreach ds,$(OSM_COUNTRIES_CE),$(OSM_CACHE_DIR)\$(ds).o5m)
OHM_INP_OSM_HU := $(foreach ds,$(OSM_COUNTRIES_HU),$(OSM_CACHE_DIR)\$(ds).o5m)
OHM_INP_CONTOUR_CE=$(CONTOUR_DIR)\contour-ce.o5m
OHM_INP_CONTOUR_HU=$(CONTOUR_DIR)\contour-hu.o5m
OHM_INP_JEL= $(TJEL_CACHE_DIR)\$(TJEL_NAME)

OHM_OUT_PBF_CE=openhiking-ce.pbf
OHM_OUT_PBF_HU=openhiking-hu.pbf
OHM_OUT_PBF_CE_FP=$(OSM_CACHE_DIR)\$(OHM_OUT_PBF_CE)
OHM_OUT_PBF_HU_FP=$(OSM_CACHE_DIR)\$(OHM_OUT_PBF_HU)


##############################################
# Tile Splitting

TILES_DIR_CE=$(DATASET_DIR)\tiles-ce
#TILES_DIR_CE=$(DATASET_DIR)\tiles-exp
TILE_ARGS_CE=$(TILES_DIR_CE)\template.args

TILES_DIR_HU=$(DATASET_DIR)\tiles-hu
TILE_ARGS_HU=$(TILES_DIR_HU)\template.args

##############################################
# Garmin map generation

GMAP_DIR_CE=c:\Dataset\gmap-ce
GMAP_DIR_HU=c:\Dataset\gmap-hu
OHM_ARGS_TEMPLATE=$(CONFIG_DIR)\ohm-template.args
TYP_FILE_CE=$(CONFIG_DIR)\ohmce.typ
TYP_FILE_HU=$(CONFIG_DIR)\ohmhu.typ
STYLE_NAME=hiking
STYLES=info lines options points polygons relations version

MERGED_ARGS_CE=$(TILES_DIR_CE)\openhiking.args
MERGED_ARGS_HU=$(TILES_DIR_HU)\openhiking.args
STYLES2 := $(foreach wrd,$(STYLES),$(STYLES_DIR)\$(STYLE_NAME)\$(wrd))

contour-ce:
	$(PHYGHTMAP) --jobs=2 --viewfinder-mask=3 -s 20 -c 200,100 -a $(COUNTOUR_BBOX_CE) --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) --hgtdir=$(HGT_DIR) \
	--max-nodes-per-tile=0 --o5m -o $(CONTOUR_FILE_PFX)ce

contour-hu:
	$(PHYGHTMAP) --jobs=2 --viewfinder-mask=3 -s 10 -c 200,100 --polygon=$(BOUNDARY_POLYGON_HU) --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) --hgtdir=$(HGT_DIR) \
	--max-nodes-per-tile=0 --o5m -o $(CONTOUR_FILE_PFX)hu

$(OSM_CACHE_DIR)\\%-latest.osm.pbf:
	$(WGET) $(GEOFABRIK_URL)$*-latest.osm.pbf -P $(OSM_CACHE_DIR)

$(TJEL_CACHED):
	$(WGET) $(TJEL_URL)$(TJEL_NAME) -P $(TJEL_CACHE_DIR)

refresh: $(OSM_PBF_CE) $(TJEL_CACHED)
	@echo "Completed"

$(OSM_CACHE_DIR)\\%.o5m: $(OSM_CACHE_DIR)\%-latest.osm.pbf
	$(OSMCONVERT) $< -o=$@

$(OHM_OUT_PBF_CE_FP):  $(OHM_INP_OSM_CE) $(OHM_INP_CONTOUR_CE) $(OHM_INP_JEL)
	$(OSMCONVERT) $(OHM_INP_OSM_CE) $(OHM_INP_CONTOUR_CE) $(OHM_INP_JEL) -o=$@

$(OHM_OUT_PBF_HU_FP): $(OHM_INP_OSM_HU) $(OHM_INP_CONTOUR_HU) $(OHM_INP_JEL)
	$(OSMCONVERT) $(OHM_INP_OSM_HU) $(OHM_INP_CONTOUR_HU) $(OHM_INP_JEL) -B=$(BOUNDARY_POLYGON_HU) -o=$@

merge: $(OHM_OUT_PBF_HU_FP)
	echo Ok

tiles-ce: $(OHM_OUT_PBF_CE_FP)
	java -Xmx4192M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR_CE)

tiles-hu: $(OHM_OUT_PBF_HU_FP)
	java -Xmx4192M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR_HU)


$(MERGED_ARGS_CE): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS_CE)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS_CE) $(MERGED_ARGS_CE)

$(MERGED_ARGS_HU): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS_HU)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS_HU) $(MERGED_ARGS_HU)


map-ce:  $(STYLES2) $(MERGED_ARGS_CE)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=3691 --family-name=OpenHikingCE --series-name=OpenHikingCE $(TYP_FILE_CE) --dem=$(DEM_DIR)  \
	--style-file=$(STYLES_DIR)\ --output-dir=$(GMAP_DIR_CE) -c $(MERGED_ARGS_CE) --max-jobs=2


map-hu:  $(STYLES2) $(MERGED_ARGS_HU)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=71221559 --family-id=3690 --family-name=OpenHiking --series-name=OpenHiking $(TYP_FILE_HU) --dem=$(DEM_DIR) \
	--dem-poly=$(BOUNDARY_POLYGON_HU) --style-file=$(STYLES_DIR)\ --output-dir=$(GMAP_DIR_HU) -c $(MERGED_ARGS_HU) --max-jobs=2


install-ce:
	$(COPY) $(CONFIG_DIR)\icon.ico $(GMAP_DIR_CE)
	$(COPY) $(TYP_FILE_CE) $(GMAP_DIR_CE)
	$(MKNSIS) $(GMAP_DIR_CE)\openhiking.nsi

install-hu:
	$(COPY) $(CONFIG_DIR)\icon.ico $(GMAP_DIR_HU)
	$(COPY) $(TYP_FILE_HU) $(GMAP_DIR_HU)
	$(MKNSIS) $(GMAP_DIR_HU)\openhiking.nsi

clean-ce:
	$(DEL) $(GMAP_DIR_CE)\*

clean-hu:
	$(DEL) $(GMAP_DIR_HU)\*


cleanall-ce:
	$(DEL) $(OHM_OUT_PBF_CE_FP)
	$(DEL) $(TILES_DIR_CE)\*
	$(DEL) $(GMAP_DIR_CE)\*

cleanall-hu:
	$(DEL) $(OHM_OUT_PBF_HU_FP)
	$(DEL) $(TILES_DIR_HU)\*
	$(DEL) $(GMAP_DIR_HU)\*


cleancache:
	$(DEL)  $(OSM_CACHE_DIR)\*.o5m
	$(DEL)  $(OSM_CACHE_DIR)\*.pbf
#	$(MOVE) $(OSM_CACHE_DIR)\*.osm.pbf *.osm.pbf.bkp
#	$(MOVE) $(TJEL_CACHE_DIR)\$(TJEL_NAME) *.osm.bkp

test:
	@echo  $(OSM_PBF_CE)