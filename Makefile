#######################################################
# OpenHikingMap
#
# Master makefile
#
# Call syntax: make MAP=<mapcode> <target>
# 
# Example: make MAP=hu map
#
########################################################



##############################################
# Tools
PHYGHTMAP=phyghtmap
OSMCONVERT=osmconvert64.exe
SPLITTER=c:\Apps\splitter\splitter.jar
MKGMAP=c:\Apps\mkgmap-4819\mkgmap.jar
MKNSIS="c:\Program Files (x86)\NSIS\Bin\makensis.exe"
WGET=wget
COPY=copy /b
MOVE=move
DEL=del

##############################################
# External data sources
GEOFABRIK_URL=http://download.geofabrik.de/europe/
TJEL_URL=https://data2.openstreetmap.hu/
TJEL_NAME=vjel.osm


##############################################
# Map configurations

ifeq ($(MAP), ce)
	FAMILY_ID=3691
	FAMILY_NAME="OpenHiking CE"
	SERIES_NAME="OpenHiking CE"
	OSM_COUNTRY_LIST=hungary slovakia czech-republic poland austria italy slovenia croatia bosnia-herzegovina montenegro serbia romania ukraine
	SUPPLEMENTARY_DATA=$(TJEL_NAME)
	CONTOUR_LINE_STEP=20
	CONTOUR_LINES=contour-ce-20-v3.o5m
	BOUNDARY_POLYGON=central-europe.poly
	MAP_THEME=hiking
	TYP_BASE=ohm
	GENERATE_SEA=yes
else ifeq ($(MAP), hu)
	FAMILY_ID=3690
	FAMILY_NAME="OpenHiking HU"
	SERIES_NAME="OpenHiking HU"
	OSM_COUNTRY_LIST=hungary
	SUPPLEMENTARY_DATA=$(TJEL_NAME)
	CONTOUR_LINE_STEP=10	
	CONTOUR_LINES=contour-hungary-10.o5m
	BOUNDARY_POLYGON=hungary.poly
	MAP_THEME=hiking
	TYP_BASE=ohm
	GENERATE_SEA=no
else ifeq ($(MAP), bike)
	FAMILY_ID=62
	FAMILY_NAME="Bike Map"
	SERIES_NAME="Bike Map"
	OSM_COUNTRY_LIST=hungary
	SUPPLEMENTARY_DATA=
	CONTOUR_LINE_STEP=10
	CONTOUR_LINES=contour-hungary-10.o5m
	BOUNDARY_POLYGON=hungary.poly
	MAP_THEME=biking
	GENERATE_SEA=no
	TYP_FILE=bikemap.typ
	ICON_FILE=icon.ico
	CODE_PAGE=65001
else ifeq ($(MAP), exp)
	FAMILY_ID=3692
	FAMILY_NAME="OpenHiking EXP"
	SERIES_NAME="OpenHiking EXP"
	OSM_COUNTRY_LIST=hungary
	SUPPLEMENTARY_DATA=$(TJEL_NAME)
	CONTOUR_LINE_STEP=10
	CONTOUR_LINES=contour-hungary-10.o5m
	BOUNDARY_POLYGON=hungary.poly
	MAP_THEME=hiking
	TYP_BASE=ohm
	GENERATE_SEA=no
endif



##############################################
# Data cache locations
DATASET_DIR=c:\Dataset\map
HGT_DIR=$(DATASET_DIR)\hgt
DEM_DIR=$(HGT_DIR)\VIEW3
OSM_CACHE_DIR=$(DATASET_DIR)\osm
CONTOUR_DIR=$(DATASET_DIR)\contour

TJEL_CACHED=$(OSM_CACHE_DIR)\$(TJEL_NAME)

EXP_MAPSOURCE_DIR:="c:\Garmin\OpenHiking EXP"

##############################################
# Builder configuration

CONFIG_DIR=config
STYLES_DIR=styles
BOUNDARY_DIR=boundaries


##############################################
# Contour Lines

CONTOUR_START_ID=100000000000
CONTOUR_FILE_FP=$(CONTOUR_DIR)\$(CONTOUR_LINES)

ifeq ($(CONTOUR_LINE_STEP),10)
	CONTOUR_LINE_MEDIUM=20
	CONTOUR_LINE_MAJOR=100
else ifeq ($(CONTOUR_LINE_STEP),20)
	CONTOUR_LINE_MEDIUM=40
	CONTOUR_LINE_MAJOR=200
endif


##############################################
# Dataset Preparation

OHM_INP_OSM := $(foreach ds,$(OSM_COUNTRY_LIST),$(OSM_CACHE_DIR)\$(ds).o5m)
OHM_INP_SUPP := $(foreach ds,$(SUPPLEMENTARY_DATA),$(OSM_CACHE_DIR)\$(ds))
OHM_INP_CONTOUR=$(CONTOUR_DIR)\$(CONTOUR_LINES)
OHM_OUT_PBF=openhiking-$(MAP).pbf
OHM_OUT_PBF_FP=$(OSM_CACHE_DIR)\$(OHM_OUT_PBF)

BOUNDARY_POLYGON_FP=$(BOUNDARY_DIR)\$(BOUNDARY_POLYGON)


##############################################
# Tile Splitting

TILES_DIR=$(DATASET_DIR)\tiles-$(MAP)
TILE_ARGS=$(TILES_DIR)\template.args

##############################################
# Garmin map generation

GMAP_DIR=$(DATASET_DIR)\gmap-$(MAP)

OHM_ARGS_TEMPLATE=$(CONFIG_DIR)\mkgmap.args

ifeq ($(TYP_FILE),)
	TYP_FILE=$(TYP_BASE)$(MAP).typ
endif

TYP_FILE_FP=$(CONFIG_DIR)\$(TYP_FILE)
LICENSE_FILE=$(CONFIG_DIR)\license.txt

STYLES=info lines options points polygons relations version

MERGED_ARGS=$(TILES_DIR)\openhiking.args
STYLES_RP := $(foreach wrd,$(STYLES),$(STYLES_DIR)\$(wrd))

ifeq ($(GENERATE_SEA),yes)
	GEN_SEA_OPTIONS=--generate-sea=extend-sea-sectors,close-gaps=500,land-tag=natural=land
else
	GEN_SEA_OPTIONS=
endif

ifeq ($(ICON_FILE),)
	ICON_FILE=icon.ico
endif

ifeq ($(CODE_PAGE),)
	CODE_PAGE=65001
endif



contour:
	$(PHYGHTMAP) --jobs=2 --viewfinder-mask=3 -s $(CONTOUR_LINE_STEP) -c $(CONTOUR_LINE_MAJOR),$(CONTOUR_LINE_MEDIUM) --polygon=$(BOUNDARY_POLYGON_FP) \
	 --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) --hgtdir=$(HGT_DIR) --max-nodes-per-tile=0 --o5m -o $(CONTOUR_FILE_FP)

$(OSM_CACHE_DIR)\\%-latest.osm.pbf:
	$(WGET) $(GEOFABRIK_URL)$*-latest.osm.pbf -P $(OSM_CACHE_DIR)

$(TJEL_CACHED):
	$(WGET) $(TJEL_URL)$(TJEL_NAME) -P $(OSM_CACHE_DIR)

$(OSM_CACHE_DIR)\\%.o5m: $(OSM_CACHE_DIR)\%-latest.osm.pbf
	$(OSMCONVERT) $< -B=$(BOUNDARY_POLYGON_FP) -o=$@


refresh:  $(OHM_INP_OSM) $(TJEL_CACHED)
	@echo "Completed"

$(OHM_OUT_PBF_FP):  $(OHM_INP_OSM) $(OHM_INP_SUPP) $(OHM_INP_CONTOUR)
	$(OSMCONVERT) $^ -B=$(BOUNDARY_POLYGON_FP) -o=$@


tiles: $(OHM_OUT_PBF_FP)
	java -Xmx4192M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR)


$(MERGED_ARGS): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS) $(MERGED_ARGS)

$(CONFIG_DIR)\ohm%.typ: $(CONFIG_DIR)\ohm.txt
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 \
	  --code-page=$(CODE_PAGE) $< --output-dir=$(GMAP_DIR)
	$(MOVE) ohm.typ $(CONFIG_DIR)\ohm$(MAP).typ

map:  $(STYLES_RP) $(MERGED_ARGS) $(TYP_FILE_FP)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 \
	--series-name=$(SERIES_NAME) $(TYP_FILE_FP) --dem=$(DEM_DIR) --dem-poly=$(BOUNDARY_POLYGON_FP) --code-page=$(CODE_PAGE) $(GEN_SEA_OPTIONS) \
	--style-file=$(STYLES_DIR)\ --style-option=$(MAP_THEME) --license-file=$(LICENSE_FILE) --output-dir=$(GMAP_DIR) -c $(MERGED_ARGS) --max-jobs=2

install:
	$(COPY) $(CONFIG_DIR)\$(ICON_FILE) $(GMAP_DIR)
	$(COPY) $(TYP_FILE_FP) $(GMAP_DIR)
	$(MKNSIS) $(GMAP_DIR)\openhiking.nsi

expcopy:
	$(COPY) $(GMAP_DIR)\7*.img $(EXP_MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)\openhiking.img $(EXP_MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)\*.mdx $(EXP_MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)\*.tdb $(EXP_MAPSOURCE_DIR)

clean:
	$(DEL) $(GMAP_DIR)\*

cleanall:
	$(DEL) $(OHM_OUT_PBF_FP)
	$(DEL) $(TILES_DIR)\*
	$(DEL) $(GMAP_DIR)\*

cleancache:
	$(DEL) $(OSM_CACHE_DIR)\*.o5m
	$(DEL) $(OSM_CACHE_DIR)\*.pbf

test: $(TYP_FILE_FP)
	@echo $(TYP_FILE_FP)

