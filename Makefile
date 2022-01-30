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
# External data sources
GEOFABRIK_URL=http://download.geofabrik.de/europe/
TJEL_URL=https://data2.openstreetmap.hu/
TJEL_NAME=vjel.osm

##############################################
# Builder configuratios

CONFIG_DIR=config
BOUNDARY_DIR=boundaries
STYLES_DIR=styles
TYP_DIR=typ


##############################################
# Map configurations

ifeq ($(MAP),)
$(error MAP variable must be set)
endif

include $(CONFIG_DIR)/$(MAP).cfg

# Default values
TILES_SOURCE?=$(MAP)
HILL_SHADING?=alos
CODE_PAGE?=1250
TYP_BASE?=ohm

##############################################
# Directory configurations

OSM_CACHE_DIR=${MKG_OSM_CACHE_DIR}
ifeq ($(OSM_CACHE_DIR),)
$(error MKG_OSM_CACHE_DIR env variable must be set)
endif

DEM_DIR=${MKG_DEM_DIR}
ifeq ($(DEM_DIR),)
$(error MKG_DEM_DIR env variable must be set)
endif

CONTOUR_DIR=${MKG_CONTOUR_DIR}
ifeq ($(CONTOUR_DIR),)
$(error MKG_CONTOUR_DIR env variable must be set)
endif

WORKING_DIR=${MKG_WORKING_DIR}
ifeq ($(WORKING_DIR),)
$(error MKG_WORKING_DIR env variable must be set)
endif

OUTPUT_DIR=${MKG_OUTPUT_DIR}
MAPSOURCE_DIR=${MKG_MAPSOURCE_DIR}  

# Conditional assignments
ifneq (${MKG_WGET},)
WGET=${MKG_WGET}
endif

ifneq (${MKG_OSMCONVERT},)
OSMCONVERT=${MKG_OSMCONVERT}
endif

ifneq (${MKG_SPLITTER},)
SPLITTER=${MKG_SPLITTER}
endif

ifneq (${MKG_MKGMAP},)
MKGMAP=${MKG_MKGMAP}
endif

ifneq (${MKG_MKNSIS},)
MKNSIS=${MKG_MKNSIS}
endif

ifneq (${MKG_ZIP},)
ZIP=${MKG_ZIP}
endif


##############################################
# Operating System Dependent Tools


ifeq (${ComSpec},)
	LINUX=1
	OSMCONVERT?=${HOME}/tools/osmconvert64
	OSMOSIS?=${HOME}/tools/osmosis-0.48.3/bin/osmosis
	SPLITTER?=$(HOME)/tools/splitter-r645/splitter.jar
	MKGMAP?=$(HOME)/tools/mkgmap-r4855/mkgmap.jar
	MKNSIS?=makensis
	ZIP?=zip
	ZIPARGS=
	PSEP=$(subst /,/,/)
	PSEP2=$(PSEP)
	CMDLIST=&&
	COPY=cp
	MOVE=mv
	DEL=rm
	CAT=cat
else
	LINUX=0
	OSMCONVERT?=osmconvert64.exe
	OSMOSIS?=c:\Apps\osmosis-0-48\bin\osmosis
	SPLITTER?=c:\Apps\splitter\splitter.jar
	MKGMAP?=c:\Apps\mkgmap-4819\mkgmap.jar
	MKNSIS?="c:\Program Files (x86)\NSIS\Bin\makensis.exe"
	ZIP?="c:\Program Files\7-Zip\7z.exe"
	ZIPARGS=a -tzip
	PSEP=$(subst /,\,/)
	PSEP2=$(PSEP)$(PSEP)
	CMDLIST=&
	COPY=copy /b
	MOVE=move
	DEL=del /f /q
endif

DEMMGR=tools$(PSEP)demmgr.py
PHYGHTMAP=phyghtmap
WGET?=wget


##############################################
# Data cache locations
ALOS_DIR=$(DEM_DIR)$(PSEP)alos
TJEL_CACHED=$(OSM_CACHE_DIR)$(PSEP)$(TJEL_NAME)

##############################################
# Contour Lines

CONTOUR_START_ID=100000000000
CONTOUR_FILE_FP=$(CONTOUR_DIR)$(PSEP)$(CONTOUR_LINES)

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

TILES_DIR=$(WORKING_DIR)$(PSEP)tiles-$(TILES_SOURCE)

OHM_OSM_LATEST_PBF := $(foreach ds,$(OSM_COUNTRY_LIST),$(OSM_CACHE_DIR)$(PSEP)$(ds)-latest.osm.pbf)

OHM_INP_OSM_O5M := $(foreach ds,$(OSM_COUNTRY_LIST),$(TILES_DIR)$(PSEP)$(ds).o5m)
OHM_INP_OSM_PBF := $(foreach ds,$(OSM_COUNTRY_LIST),$(TILES_DIR)$(PSEP)$(ds)-clipped.pbf)
OHM_INP_OSM_PBF_ARGS=$(foreach wrd,$(OHM_INP_OSM_PBF),--read-pbf file=$(wrd))

OHM_INP_SUPP := $(foreach ds,$(SUPPLEMENTARY_DATA),$(OSM_CACHE_DIR)$(PSEP)$(ds))
OHM_INP_SUPP_PBF := $(foreach ds,$(SUPPLEMENTARY_DATA),$(OSM_CACHE_DIR)$(PSEP)$(ds))
OHM_INP_SUPP_PBF_ARGS=$(foreach wrd,$(OHM_INP_SUPP_PBF),--read-pbf file=$(wrd))

OHM_INP_CONTOUR=$(CONTOUR_DIR)$(PSEP)$(CONTOUR_LINES)
OHM_INP_CONTOUR_ARGS=--read-pbf file=$(OHM_INP_CONTOUR)

OHM_MERGED_PBF=master$(MAP).pbf

BOUNDARY_POLYGON_FP=$(BOUNDARY_DIR)$(PSEP)$(BOUNDARY_POLYGON)

##############################################
# Tile Splitting

TILE_ARGS=$(TILES_DIR)$(PSEP)template.args
OHM_MERGED_PBF_FP=$(TILES_DIR)$(PSEP)$(OHM_MERGED_PBF)

##############################################
# Garmin map generation

GMAP_DIR=$(WORKING_DIR)$(PSEP)gmap-$(MAP)

ifeq ($(LINUX),0)
GMAP_DRIVE=$(word 1,$(subst :, ,$(GMAP_DIR))):
endif


OHM_ARGS_TEMPLATE=$(CONFIG_DIR)$(PSEP)mkgmap.args


ifeq ($(TYP_FILE),)
	TYPE_BASENAME=$(TYP_BASE)$(MAP)
	TYP_FILE=$(TYPE_BASENAME).typ
endif

TYP_FILE_FP=$(GMAP_DIR)$(PSEP)$(TYP_FILE)
LICENSE_FILE=$(CONFIG_DIR)$(PSEP)license.txt

STYLES=info lines options points polygons relations version

MERGED_ARGS=$(TILES_DIR)$(PSEP)mkgmap.args
STYLES_RP := $(foreach wrd,$(STYLES),$(STYLES_DIR)$(PSEP)$(wrd))

HILL_SHADING_DIR=$(DEM_DIR)$(PSEP)$(HILL_SHADING)

ifeq ($(GENERATE_SEA),yes)
	GEN_SEA_OPTIONS=--generate-sea=extend-sea-sectors,close-gaps=500,land-tag=natural=land
else
	GEN_SEA_OPTIONS=
endif

ifeq ($(USE_LOWERCASE),yes)
	LOWER_CASE=--lower-case
else:
	LOWER_CASE=
endif


ifeq ($(GMAPSUPP),yes)
	GMAPSUPP_OPTION=--gmapsupp
endif


##############################################
# Installer & ZIP

empty:=
space:= $(empty) $(empty)
INSTALLER_NAME:=$(subst $(space),$(empty),$(FAMILY_NAME))

ifeq ($(ICON_FILE),)
	ICON_FILE=OpenHiking.ico
endif

ZIPNAME=$(MAPNAME).zip


##############################################
# Recipes

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


$(OSM_CACHE_DIR)$(PSEP2)%-latest.osm.pbf:
	$(WGET) $(GEOFABRIK_URL)$*-latest.osm.pbf -P $(OSM_CACHE_DIR)

$(TJEL_CACHED):
	$(WGET) --no-check-certificate $(TJEL_URL)$(TJEL_NAME) -P $(OSM_CACHE_DIR)


refresh:  $(OHM_OSM_LATEST_PBF) $(TJEL_CACHED)
	@echo "Completed"


$(TILES_DIR)$(PSEP2)%.o5m: $(OSM_CACHE_DIR)$(PSEP)%-latest.osm.pbf
	$(OSMCONVERT) $< -B=$(BOUNDARY_POLYGON_FP) -o=$@

$(TILES_DIR)$(PSEP2)%-clipped.pbf: $(OSM_CACHE_DIR)$(PSEP)%-latest.osm.pbf
	$(OSMCONVERT) $< -B=$(BOUNDARY_POLYGON_FP) -o=$@
	
$(OHM_MERGED_PBF_FP):  $(OHM_INP_OSM_O5M) $(OHM_INP_SUPP) $(OHM_INP_CONTOUR)
	$(OSMCONVERT) --hash-memory=240-30-2  --drop-version $^ -B=$(BOUNDARY_POLYGON_FP) -o=$@


merge: $(OHM_MERGED_PBF_FP)
	@echo "Merge completed"


merge-osmosis:  $(OHM_INP_OSM_PBF) $(OHM_INP_SUPP_PBF) $(OHM_INP_CONTOUR)
	$(OSMOSIS) $(OHM_INP_OSM_PBF_ARGS) $(OHM_INP_SUPP_PBF_ARGS) $(OHM_INP_CONTOUR_ARGS) --merge --bp file=$(BOUNDARY_POLYGON_FP) --wb file=$@
	@echo "Merge completed"


tiles: $(OHM_MERGED_PBF_FP)
	java -Xmx5000M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR)


$(MERGED_ARGS): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS)
ifeq ($(LINUX),1)
	$(COPY) $(OHM_ARGS_TEMPLATE) $(MERGED_ARGS)
	$(CAT)  $(TILE_ARGS) >> $(MERGED_ARGS)
else
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS) $(MERGED_ARGS)
endif

$(GMAP_DIR)$(PSEP)bikemap.typ: $(TYP_DIR)$(PSEP)bikemap.typ
	$(COPY) $< $(GMAP_DIR)

$(GMAP_DIR)$(PSEP)$(TYP_BASE)%.typ: $(TYP_DIR)$(PSEP)$(TYP_BASE).txt
	$(COPY) $< $(GMAP_DIR)$(PSEP)$(TYPE_BASENAME).txt
ifeq ($(LINUX),1)
	cd $(GMAP_DIR) && java -Xmx1024M -ea -jar $(MKGMAP) --mapname=74221559 \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYPE_BASENAME).txt --output-dir=$(GMAP_DIR)
else
	$(GMAP_DRIVE) & cd $(GMAP_DIR) & java -Xmx1024M -ea -jar $(MKGMAP) --mapname=74221559 \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYPE_BASENAME).txt --output-dir=$(GMAP_DIR)
endif
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.img
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.tdb


typ: $(TYP_FILE_FP)
	@echo "Completed"

map:  $(MERGED_ARGS) $(TYP_FILE_FP)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) \
	 --product-id=1 --series-name=$(SERIES_NAME) --overview-mapname=$(MAPNAME) --description:$(MAPNAME) \
	 $(TYP_FILE_FP) --dem=$(HILL_SHADING_DIR) --dem-poly=$(BOUNDARY_POLYGON_FP) \
	 --code-page=$(CODE_PAGE) $(GEN_SEA_OPTIONS) $(LOWER_CASE) \
	 --style-file=$(STYLES_DIR) --style=$(MAP_STYLE) $(GMAPSUPP_OPTION) \
	 --license-file=$(LICENSE_FILE) --output-dir=$(GMAP_DIR) -c $(MERGED_ARGS) --max-jobs=2


check:
	java -Xmx4192M -ea -jar $(MKGMAP) --style-file=$(STYLES_DIR) --style=$(MAP_STYLE) --check-styles


nsi-script:
	$(COPY) $(CONFIG_DIR)$(PSEP)$(ICON_FILE) $(GMAP_DIR)
	python tools\nsigen.py --family-name=$(FAMILY_NAME) --family-id=$(FAMILY_ID) --mapname=$(MAPNAME) --product-id=1 \
	--typ-name=$(TYP_FILE) --icon-name=$(ICON_FILE) --installer-name=$(INSTALLER_NAME) \
	config\installer_template.txt $(GMAP_DIR)

install:
	$(MKNSIS) $(GMAP_DIR)$(PSEP)$(MAPNAME).nsi

zip:
ifeq ($(OUTPUT_DIR),)
$(error MKG_OUTPUT_DIR env variable is not set!)
endif
	$(DEL) "$(OUTPUT_DIR)$(PSEP)$(ZIPNAME)"
	$(ZIP) $(ZIPARGS) "$(OUTPUT_DIR)$(PSEP)$(ZIPNAME)" "$(GMAP_DIR)$(PSEP)*.img" "$(GMAP_DIR)$(PSEP)*.mdx" "$(GMAP_DIR)$(PSEP)*.tdb" "$(GMAP_DIR)$(PSEP)*.typ"

all: refresh tiles map install
	echo Map making completed successfully

push:
ifeq ($(MAPSOURCE_DIR),)
	$(warning MKG_MAPSOURCE_DIR env variable is not set!!)
endif
	$(COPY) $(GMAP_DIR)$(PSEP)7*.img $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)$(PSEP)$(MAPNAME).img $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)$(PSEP)*.mdx $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)$(PSEP)*.tdb $(MAPSOURCE_DIR)

pushall: push
ifeq ($(MAPSOURCE_DIR),)
	$(error MKG_MAPSOURCE_DIR env variable is not set!!)
endif
	$(COPY) $(GMAP_DIR)$(PSEP)*.typ $(MAPSOURCE_DIR)

clean:
	$(DEL) $(GMAP_DIR)$(PSEP)*

cleanall:
	$(DEL) $(TILES_DIR)$(PSEP)*
	$(DEL) $(GMAP_DIR)$(PSEP)*

cleancache:
	$(DEL) $(OSM_CACHE_DIR)$(PSEP)*.osm
	$(DEL) $(OSM_CACHE_DIR)$(PSEP)*.o5m
	$(DEL) $(OSM_CACHE_DIR)$(PSEP)*.pbf

cleanoutput:
	$(DEL) $(OUTPUT_DIR)$(PSEP)$(MAP)_map.zip


test:
	@echo $(OHM_OSM_LATEST_PBF)


