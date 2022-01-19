#######################################################
# OpenHikingMap
#
# Map building automation
#
# Copyright (c) 2021-2022 OpenHiking contributors
# SPDX-License-Identifier: GPL-3.0-only
#
########################################################


##############################################
# Tools
DEMMGR=tools\demmgr.py
PHYGHTMAP=phyghtmap
OSMCONVERT=osmconvert64.exe
SPLITTER=c:\Apps\splitter\splitter.jar
MKGMAP=c:\Apps\mkgmap-4819\mkgmap.jar
MKNSIS="c:\Program Files (x86)\NSIS\Bin\makensis.exe"
WGET=wget
COPY=copy /b
MOVE=move
DEL=del /f /q

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
	OSM_COUNTRY_LIST=hungary romania slovenia slovakia czech-republic poland austria italy croatia bosnia-herzegovina montenegro serbia ukraine
	SUPPLEMENTARY_DATA=$(TJEL_NAME)
	DEM_SOURCES=dtm-sk alos
	HILL_SHADING=alos
	CONTOUR_LINE_STEP=10
	CONTOUR_LINES=contour-ce-alos-10.o5m
	BOUNDARY_POLYGON=central-europe-v4.poly
	MAP_STYLE=hiking
	TYP_BASE=ohm
	GENERATE_SEA=yes
	GMAPSUPP=yes
else ifeq ($(MAP), hu)
	FAMILY_ID=3690
	FAMILY_NAME="OpenHiking HU"
	SERIES_NAME="OpenHiking HU"
	OSM_COUNTRY_LIST=hungary
	SUPPLEMENTARY_DATA=$(TJEL_NAME)
	DEM_SOURCES=alos
	HILL_SHADING=alos
	CONTOUR_LINE_STEP=10
	CONTOUR_LINES=contour-hungary-alos-10.o5m
	BOUNDARY_POLYGON=hungary.poly
	MAP_STYLE=hiking
	GMAPSUPP=yes
else ifeq ($(MAP), bike)
	FAMILY_ID=63
	FAMILY_NAME="Bike Map"
	SERIES_NAME="Bike Map"
	OSM_COUNTRY_LIST=hungary
	SUPPLEMENTARY_DATA=
	DEM_SOURCES=VIEW3
	HILL_SHADING=VIEW3
	CONTOUR_LINE_STEP=10
	CONTOUR_LINES=contour-hungary-10.o5m
	BOUNDARY_POLYGON=hungary.poly
	MAP_STYLE=biking
	GENERATE_SEA=no
#	TYP_BASE=ohm
	TYP_FILE=bikemap.typ
	ICON_FILE=icon.ico
	MAPSOURCE_DIR:="c:\Garmin\Bike Map"
	GMAPSUPP=no
else ifeq ($(MAP), exp)
	FAMILY_ID=3698
	FAMILY_NAME="OpenHiking EXP"
	SERIES_NAME="OpenHiking EXP"
	OSM_COUNTRY_LIST=slovakia
	SUPPLEMENTARY_DATA=
	DEM_SOURCES=dtm-sk
	HILL_SHADING=alos
	CONTOUR_LINE_STEP=10
	CONTOUR_LINES=contour-slovakia-dtm-10.o5m
	BOUNDARY_POLYGON=slovakia.poly
	MAP_STYLE=hiking
	MAPSOURCE_DIR="c:\Garmin\OpenHiking EXP"
else ifeq ($(MAP), exp2)
	FAMILY_ID=3699
	FAMILY_NAME="OpenHiking EXP2"
	SERIES_NAME="OpenHiking EXP2"
	OSM_COUNTRY_LIST=hungary
	SUPPLEMENTARY_DATA=
	DEM_SOURCES=test
	HILL_SHADING=VIEW3
	CONTOUR_LINE_STEP=10
#	CONTOUR_LINES=contour-hungary-alos-10.o5m
	CONTOUR_LINES=contour-borzsony-alos-10.o5m
	BOUNDARY_POLYGON=borzsony.poly
	MAP_STYLE=hiking
	MAPSOURCE_DIR="c:\Garmin\OpenHiking EXP2"	
endif





##############################################
# Data cache locations
DATASET_DIR=c:\Dataset\map
WORKING_DIR=r:
#WORKING_DIR=$(DATASET_DIR)
DEM_DIR=$(DATASET_DIR)\hgt
ALOS_DIR=$(DEM_DIR)\alos
CONTOUR_DIR=$(DATASET_DIR)\contour
OSM_CACHE_DIR=$(DATASET_DIR)\osm

TJEL_CACHED=$(OSM_CACHE_DIR)\$(TJEL_NAME)

##############################################
# Builder configuration

CONFIG_DIR=config
STYLES_DIR=styles
BOUNDARY_DIR=boundaries


##############################################
# Contour Lines

CONTOUR_START_ID=100000000000
CONTOUR_FILE_FP=$(CONTOUR_DIR)\$(CONTOUR_LINES)

ifeq ($(DEM_SOURCES),)
	DEM_SOURCES=dtm-sk alos SRTM1v3.0
endif

DEM_SOURCE_TILES=$(shell python $(DEMMGR) -s -i -p $(BOUNDARY_POLYGON_FP) -d $(DEM_DIR) $(DEM_SOURCES))

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

TILES_DIR=$(WORKING_DIR)\tiles-$(MAP)
TILE_ARGS=$(TILES_DIR)\template.args

##############################################
# Garmin map generation

GMAP_DIR=$(WORKING_DIR)\gmap-$(MAP)

OHM_ARGS_TEMPLATE=$(CONFIG_DIR)\mkgmap.args

ifeq ($(TYP_BASE),)
	TYP_BASE=ohm
endif

ifeq ($(TYP_FILE),)
	TYP_FILE=$(TYP_BASE)$(MAP).typ
endif

TYP_FILE_FP=$(CONFIG_DIR)\$(TYP_FILE)
LICENSE_FILE=$(CONFIG_DIR)\license.txt

STYLES=info lines options points polygons relations version

MERGED_ARGS=$(TILES_DIR)\openhiking.args
STYLES_RP := $(foreach wrd,$(STYLES),$(STYLES_DIR)\$(wrd))

HILL_SHADING_DIR=$(DEM_DIR)\$(HILL_SHADING)

ifeq ($(GENERATE_SEA),yes)
	GEN_SEA_OPTIONS=--generate-sea=extend-sea-sectors,close-gaps=500,land-tag=natural=land
else
	GEN_SEA_OPTIONS=
endif

ifeq ($(GMAPSUPP),yes)
	GMAPSUPP_OPTION=--gmapsupp
endif

ifeq ($(ICON_FILE),)
	ICON_FILE=icon.ico
endif

ifeq ($(CODE_PAGE),)
	CODE_PAGE=1250
endif


alos:
	python $(DEMMGR) -r -p $(BOUNDARY_POLYGON_FP) $(ALOS_DIR)

contour-srtm:
	$(PHYGHTMAP) --jobs=2 --viewfinder-mask=3 -s $(CONTOUR_LINE_STEP) -c $(CONTOUR_LINE_MAJOR),$(CONTOUR_LINE_MEDIUM) -0 \
	 --polygon=$(BOUNDARY_POLYGON_FP) --hgtdir=$(DEM_DIR) $(CONTOUR_RDP) \
	 --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) --max-nodes-per-tile=0 \
	  --o5m -o $(CONTOUR_FILE_FP)

contour-hr:
	cd $(DEM_DIR) &&  $(PHYGHTMAP) --jobs=2 -s $(CONTOUR_LINE_STEP) -c $(CONTOUR_LINE_MAJOR),$(CONTOUR_LINE_MEDIUM)  \
	 --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) $(CONTOUR_RDP) \
	 --max-nodes-per-tile=0 --o5m -o $(CONTOUR_FILE_FP) $(DEM_SOURCE_TILES)


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
	java -Xmx6144M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR)


$(MERGED_ARGS): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS) $(MERGED_ARGS)

$(CONFIG_DIR)\ohm%.typ: $(CONFIG_DIR)\ohm.txt
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 \
	  --code-page=$(CODE_PAGE) $< --output-dir=$(GMAP_DIR)
	$(MOVE) ohm.typ $(CONFIG_DIR)\ohm$(MAP).typ

typ: $(TYP_FILE_FP)
	@echo "Completed"

map:  $(MERGED_ARGS) $(TYP_FILE_FP)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 \
	--series-name=$(SERIES_NAME) $(TYP_FILE_FP) --dem=$(HILL_SHADING_DIR) --dem-poly=$(BOUNDARY_POLYGON_FP) --code-page=$(CODE_PAGE) $(GEN_SEA_OPTIONS) \
	--style-file=$(STYLES_DIR)\ --style=$(MAP_STYLE) $(GMAPSUPP_OPTION) --license-file=$(LICENSE_FILE) --output-dir=$(GMAP_DIR) -c $(MERGED_ARGS) --max-jobs=2


check:
	java -Xmx4192M -ea -jar $(MKGMAP) --style-file=$(STYLES_DIR) --style=$(MAP_STYLE) --check-styles


install:
	$(COPY) $(CONFIG_DIR)\$(ICON_FILE) $(GMAP_DIR)
	$(COPY) $(TYP_FILE_FP) $(GMAP_DIR)
	$(MKNSIS) $(GMAP_DIR)\openhiking.nsi

push:
	$(COPY) $(GMAP_DIR)\7*.img $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)\openhiking.img $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)\*.mdx $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)\*.tdb $(MAPSOURCE_DIR)

pushall: push
	$(COPY) $(GMAP_DIR)\*.typ $(MAPSOURCE_DIR)

clean:
	$(DEL) $(GMAP_DIR)\*

cleanall:
	$(DEL) $(OHM_OUT_PBF_FP)
	$(DEL) $(TILES_DIR)\*
	$(DEL) $(GMAP_DIR)\*

cleancache:
	$(DEL) $(OSM_CACHE_DIR)\*.osm
	$(DEL) $(OSM_CACHE_DIR)\*.o5m
	$(DEL) $(OSM_CACHE_DIR)\*.pbf

test:
	@echo $(STYLES_DIR)
	@echo $(MAP_STYLE)

