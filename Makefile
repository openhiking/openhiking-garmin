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

BOUNDS_CACHE_DIR=${MKG_BOUNDS_CACHE_DIR}
ifeq ($(BOUNDS_CACHE_DIR),)
$(warning MKG_BOUNDS_CACHE_DIR env variable must be set)
endif

WORKING_DIR=${MKG_WORKING_DIR}
ifeq ($(WORKING_DIR),)
$(error MKG_WORKING_DIR env variable must be set)
endif

SEA_AREA_DIR=$(MKG_SEA_AREA_DIR)
OUTPUT_DIR=${MKG_OUTPUT_DIR}
MAPSOURCE_DIR=${MKG_MAPSOURCE_DIR}

# Conditional assignments
ifneq (${MKG_BOUNDS_DIR},)
BOUNDS_DIR=${MKG_BOUNDS_DIR}
endif

ifneq (${MKG_WGET},)
WGET=${MKG_WGET}
endif

ifneq (${MKG_OSMCONVERT},)
OSMCONVERT=${MKG_OSMCONVERT}
endif

ifneq (${MKG_OSMFILTER},)
OSMFILTER=${MKG_OSMFILTER}
endif

ifneq (${MKG_PHYGHTMAP},)
PHYGHTMAP=${MKG_PHYGHTMAP}
endif

ifneq (${MKG_PHYGHTMAP_JOBS},)
PHYGHTMAP_JOBS=${MKG_PHYGHTMAP_JOBS}
endif

ifneq (${MKG_MAKESYMBOLS},)
MAKESYMBOLS=${MKG_MAKESYMBOLS}
endif

ifneq (${MKG_SPLITTER},)
SPLITTER=${MKG_SPLITTER}
endif

ifneq (${MKG_SPLITTER_MEMORY},)
SPLITTER_MEMORY=${MKG_SPLITTER_MEMORY}
endif

ifneq (${MKG_SPLITTER_THREADS},)
SPLITTER_THREADS=--max-threads=${MKG_SPLITTER_THREADS}
endif

ifneq (${MKG_SPLITTER_MAX_AREAS},)
SPLITTER_MAX_AREAS=${MKG_SPLITTER_MAX_AREAS}
endif

ifneq (${MKG_SPLITTER_STATUS_FREQ},)
SPLITTER_STATUS_FREQ=${MKG_SPLITTER_STATUS_FREQ}
endif

ifneq (${MKG_MKGMAP},)
MKGMAP=${MKG_MKGMAP}
endif

ifneq (${MKG_MKGMAP_JOBS},)
MKGMAP_JOBS=${MKG_MKGMAP_JOBS}
endif


ifneq (${MKG_NSIGEN},)
NSIGEN=${MKG_NSIGEN}
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
	OSMCONVERT?=osmconvert64
	OSMFILTER?=osmfilter
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
	OSMFILTER?=osmfilter.exe
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
PHYGHTMAP?=phyghtmap
WGET?=wget
NSIGEN?=python tools\nsigen.py

##############################################
# Data cache locations
ALOS_DIR=$(DEM_DIR)$(PSEP)alos

ifneq ($(SUPPLEMENTARY_DATA),)
	SUPPLEMENTARY_CACHED=$(OSM_CACHE_DIR)$(PSEP)$(SUPPLEMENTARY_DATA)
endif

##############################################
# Contour Lines

PHYGHTMAP_JOBS?=2

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
# Preprocessing

TILES_DIR=$(WORKING_DIR)$(PSEP)tiles-$(TILES_SOURCE)
BOUNDARY_POLYGON_FP=$(BOUNDARY_DIR)$(PSEP)$(BOUNDARY_POLYGON)

PREFILTER_CONDITION?="building=residential building=apartments building=detached building=house building=garage building=garages natural=tree_row"

MAP_OSM_LATEST_PBF := $(foreach ds,$(OSM_COUNTRY_LIST),$(OSM_CACHE_DIR)$(PSEP)$(ds)-latest.osm.pbf)

ifeq ($(PREFILTERING),yes)
	MAP_INP_OSM_O5M := $(foreach ds,$(OSM_COUNTRY_LIST),$(TILES_DIR)$(PSEP)$(ds)-flt.o5m)
else
	MAP_INP_OSM_O5M := $(foreach ds,$(OSM_COUNTRY_LIST),$(TILES_DIR)$(PSEP)$(ds)-clipped.o5m)
endif



##############################################
# Hiking Symbol Generation

MAP_COUNTRY_ROUTES_O5M := $(foreach ds,$(OSM_COUNTRY_LIST),$(TILES_DIR)$(PSEP)$(ds)-routes.o5m)
MAP_ROUTES_FILE=routes
MAP_ROUTES_PBF_FP=$(TILES_DIR)$(PSEP)$(MAP_ROUTES_FILE).pbf
ROUTE_CONDITION?="route=hiking or ( route=piste and ( jel=px or jel=kx ) )"

MAP_HIKING_SYMBOLS_OSM_FP=$(TILES_DIR)$(PSEP)symbols.osm

ifeq ($(GENERATE_HIKING_SYMBOLS),yes)
	MAP_INP_SYMBOLS_OSM=$(MAP_HIKING_SYMBOLS_OSM_FP)
endif

SYMBOLS_START_ID=120000000000


##############################################
# Merging

MAP_INP_OSM_PBF := $(foreach ds,$(OSM_COUNTRY_LIST),$(TILES_DIR)$(PSEP)$(ds)-clipped.pbf)
MAP_INP_OSM_PBF_ARGS=$(foreach wrd,$(MAP_INP_OSM_PBF),--read-pbf file=$(wrd))


MAP_INP_SUPP := $(foreach ds,$(SUPPLEMENTARY_DATA),$(OSM_CACHE_DIR)$(PSEP)$(ds))
MAP_INP_SUPP_PBF := $(foreach ds,$(SUPPLEMENTARY_DATA),$(OSM_CACHE_DIR)$(PSEP)$(ds))
MAP_INP_SUPP_PBF_ARGS=$(foreach wrd,$(OHM_INP_SUPP_PBF),--read-pbf file=$(wrd))

MAP_INP_CONTOUR=$(CONTOUR_DIR)$(PSEP)$(CONTOUR_LINES)
MAP_INP_CONTOUR_ARGS=--read-pbf file=$(MAP_INP_CONTOUR)

MAP_MERGED_PBF=master$(MAP).pbf
MAP_MERGED_O5M=master$(MAP).o5m
MAP_MERGED_PBF_FP=$(TILES_DIR)$(PSEP)$(MAP_MERGED_PBF)
MAP_MERGED_O5M_FP=$(TILES_DIR)$(PSEP)$(MAP_MERGED_O5M)


##############################################
# Bounds Generation

BOUNDS_DIR?=$(BOUNDS_CACHE_DIR)$(PSEP)bounds-$(TILES_SOURCE)
MAP_BOUNDS_O5M=bounds.o5m
MAP_BOUNDS_O5M_FP=$(TILES_DIR)$(PSEP)$(MAP_BOUNDS_O5M)
BOUNDS_CONDITION?="boundary=administrative and ( admin_level=8 or admin_level=9 )"

##############################################
# Tile Splitting

TILE_ARGS=$(TILES_DIR)$(PSEP)template.args
SPLITTER_MEMORY?=5000M
SPLITTER_MAX_AREAS?=255
SPLITTER_STATUS_FREQ?=120

##############################################
# Garmin map generation

GMAP_DIR=$(WORKING_DIR)$(PSEP)gmap-$(MAP)
MKGMAP_JOBS?=2

ifeq ($(LINUX),0)
GMAP_DRIVE=$(word 1,$(subst :, ,$(GMAP_DIR))):
endif


OHM_ARGS_TEMPLATE=$(CONFIG_DIR)$(PSEP)mkgmap.args


ifeq ($(TYP_FILE),)
	TYPE_BASENAME=$(TYP_BASE)$(MAP)
	TYP_FILE=$(TYPE_BASENAME).typ
endif

TYP_FILE_FP=$(GMAP_DIR)$(PSEP)$(TYP_FILE)

STYLES=info lines options points polygons relations version

MERGED_ARGS=$(TILES_DIR)$(PSEP)mkgmap.args
STYLES_RP := $(foreach wrd,$(STYLES),$(STYLES_DIR)$(PSEP)$(wrd))

HILL_SHADING_DIR=$(DEM_DIR)$(PSEP)$(HILL_SHADING)

ifeq ($(GENERATE_SEA),yes)
#	GEN_SEA_OPTIONS=--generate-sea=extend-sea-sectors,close-gaps=500,land-tag=natural=land
	PRECOMP_SEA_OPTION=--precomp-sea=$(SEA_AREA_DIR)
else
#	GEN_SEA_OPTIONS=
endif

ifeq ($(USE_BOUNDS),yes)
	BOUNDS_OPTS=--bounds="$(BOUNDS_DIR)"
else
	BOUNDS_OPTS=
endif

ifeq ($(USE_LOWERCASE),yes)
	LOWER_CASE=--lower-case
else
	LOWER_CASE=
endif


ifeq ($(GMAPSUPP),yes)
	GMAPSUPP_OPTION=--gmapsupp
endif


ifneq ($(LICENSE_FILE),)
	LICENSE_OPTION=--license-file=$(CONFIG_DIR)$(PSEP)$(LICENSE_FILE)
endif

ifneq ($(COPYRIGHT_FILE),)
	COPYRIGHT_OPTION=--copyright-file=$(CONFIG_DIR)$(PSEP)$(COPYRIGHT_FILE)
endif




##############################################
# Installer & ZIP

empty:=
space:= $(empty) $(empty)
INSTALLER_NAME:=$(subst $(space),$(empty),$(FAMILY_NAME))

INSTALLER_DEPS=
ifneq ($(ICON_FILE),)
	NSIGEN_ICON=--icon-name=$(ICON_FILE)
	INSTALLER_DEPS+=$(GMAP_DIR)$(PSEP)$(ICON_FILE)
endif

ifneq ($(LOGO_FILE),)
	NSIGEN_LOGO=--logo-name=$(LOGO_FILE)
	INSTALLER_DEPS+=$(GMAP_DIR)$(PSEP)$(LOGO_FILE)
endif


ZIPNAME=$(MAPNAME).zip



##############################################
# Recipes

alos:
	python $(DEMMGR) -r --poly=$(BOUNDARY_POLYGON_FP) --dem=$(DEM_DIR)

contour-srtm:
	$(PHYGHTMAP) --jobs=2 --viewfinder-mask=3 -s $(CONTOUR_LINE_STEP) -c $(CONTOUR_LINE_MAJOR),$(CONTOUR_LINE_MEDIUM) -0 \
	 --polygon=$(BOUNDARY_POLYGON_FP) --hgtdir=$(DEM_DIR) $(CONTOUR_RDP) \
	 --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) --max-nodes-per-tile=0 \
	  --o5m -o $(CONTOUR_FILE_FP)

contour-hr:
	cd $(DEM_DIR) &&  $(PHYGHTMAP) --jobs=$(PHYGHTMAP_JOBS) \
	 -s $(CONTOUR_LINE_STEP) -c $(CONTOUR_LINE_MAJOR),$(CONTOUR_LINE_MEDIUM)  \
	 --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) $(CONTOUR_RDP) \
	 --max-nodes-per-tile=0 --o5m -o $(CONTOUR_FILE_FP) $(DEM_SOURCE_TILES)


$(OSM_CACHE_DIR)$(PSEP2)%-latest.osm.pbf:
	$(WGET) $(GEOFABRIK_URL)$*-latest.osm.pbf -P $(OSM_CACHE_DIR)


refresh:  $(MAP_OSM_LATEST_PBF) $(SUPPLEMENTARY_CACHED)
	@echo "Completed"

$(TILES_DIR)$(PSEP2)%-clipped.o5m: $(OSM_CACHE_DIR)$(PSEP)%-latest.osm.pbf
	$(OSMCONVERT) $< -B=$(BOUNDARY_POLYGON_FP) -o=$@

$(TILES_DIR)$(PSEP2)%-flt.o5m: $(TILES_DIR)$(PSEP)%-clipped.o5m
	$(OSMFILTER) $< --drop=$(PREFILTER_CONDITION) --drop-author --drop-version -o=$@

$(TILES_DIR)$(PSEP2)%-routes.o5m: $(TILES_DIR)$(PSEP)%-clipped.o5m
	$(OSMFILTER) $< --keep-nodes= --keep-ways-relations=$(ROUTE_CONDITION)  -o=$@

$(TILES_DIR)$(PSEP2)%-clipped.pbf: $(OSM_CACHE_DIR)$(PSEP)%-latest.osm.pbf
	$(OSMCONVERT) $< -B=$(BOUNDARY_POLYGON_FP) -o=$@

$(MAP_ROUTES_PBF_FP):  $(MAP_COUNTRY_ROUTES_O5M)
	$(OSMCONVERT) --hash-memory=240-30-2  --drop-version $^  -o=$@


$(MAP_HIKING_SYMBOLS_OSM_FP): $(MAP_ROUTES_PBF_FP)
	$(MAKESYMBOLS) -p --exclude=$(SYMBOLS_EXCLUDE) --start-node-id=$(SYMBOLS_START_ID) --target-file=$(MAP_HIKING_SYMBOLS_OSM_FP) $(MAP_ROUTES_PBF_FP)

symbols: $(MAP_HIKING_SYMBOLS_OSM_FP)
	@echo "Done"


$(MAP_MERGED_PBF_FP):  $(MAP_INP_OSM_O5M) $(MAP_INP_SYMBOLS_OSM) $(MAP_INP_SUPP) $(MAP_INP_CONTOUR)
	$(OSMCONVERT) --hash-memory=240-30-2  --drop-version $^ -B=$(BOUNDARY_POLYGON_FP) -o=$@


merge: $(MAP_MERGED_PBF_FP)
	@echo "Merge completed"


merge-osmosis:  $(MAP_INP_OSM_PBF) $(MAP_INP_SUPP_PBF) $(MAP_INP_CONTOUR)
	$(OSMOSIS) $(MAP_INP_OSM_PBF_ARGS) $(MAP_INP_SUPP_PBF_ARGS) $(MAP_INP_CONTOUR_ARGS) --merge --bp file=$(BOUNDARY_POLYGON_FP) --wb file=$@
	@echo "Merge completed"

$(MAP_MERGED_O5M_FP): $(MAP_MERGED_PBF_FP)
	$(OSMCONVERT) $^ -o=$@

$(MAP_BOUNDS_O5M_FP): $(MAP_MERGED_O5M_FP)
	$(OSMFILTER) $< --keep-nodes= --keep-ways-relations=$(BOUNDS_CONDITION)  -o=$@


bounds: $(MAP_BOUNDS_O5M_FP)
	java -cp $(MKGMAP) uk.me.parabola.mkgmap.reader.osm.boundary.BoundaryPreprocessor "$<" "$(BOUNDS_DIR)"
	@echo "Bounds created"

tiles: $(MAP_MERGED_PBF_FP)
	java -Xmx$(SPLITTER_MEMORY) -ea -jar $(SPLITTER) --mapid=$(GARMIN_SEGMENT_ID)  --max-nodes=1600000 --max-areas=$(SPLITTER_MAX_AREAS) \
	--status-freq=$(SPLITTER_STATUS_FREQ) $(SPLITTER_THREADS) $< --output-dir=$(TILES_DIR)


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
	cd $(GMAP_DIR) && java -Xmx1024M -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYPE_BASENAME).txt --output-dir=$(GMAP_DIR)
else
	$(GMAP_DRIVE) & cd $(GMAP_DIR) & java -Xmx1024M -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYPE_BASENAME).txt --output-dir=$(GMAP_DIR)
endif
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.img
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.tdb


typ: $(TYP_FILE_FP)
	@echo "Completed"

map:  $(MERGED_ARGS) $(TYP_FILE_FP)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) --family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) \
	 --product-id=1 --series-name=$(SERIES_NAME) --overview-mapname=$(MAPNAME) --description:$(MAPNAME) \
	 $(TYP_FILE_FP) --dem=$(HILL_SHADING_DIR) --dem-poly=$(BOUNDARY_POLYGON_FP) \
	 --code-page=$(CODE_PAGE) $(PRECOMP_SEA_OPTION) $(LOWER_CASE) $(BOUNDS_OPTS) \
	 --style-file=$(STYLES_DIR) --style=$(MAP_STYLE)  \
	 $(LICENSE_OPTION) $(COPYRIGHT_OPTION) $(GMAPSUPP_OPTION) \
	 --output-dir=$(GMAP_DIR) -c $(MERGED_ARGS) --max-jobs=$(MKGMAP_JOBS)


check:
	java -Xmx4192M -ea -jar $(MKGMAP) --style-file=$(STYLES_DIR) --style=$(MAP_STYLE) --check-styles


nsi-script:
	$(COPY) $(CONFIG_DIR)$(PSEP)$(ICON_FILE) $(GMAP_DIR)
	$(NSIGEN) --family-name=$(FAMILY_NAME) --family-id=$(FAMILY_ID) --mapname=$(MAPNAME) --product-id=1 \
	--typ-name=$(TYP_FILE) $(NSIGEN_ICON) $(NSIGEN_LOGO) --installer-name=$(INSTALLER_NAME) \
	config$(PSEP)installer_template.txt $(GMAP_DIR)

$(GMAP_DIR)$(PSEP2)%.ico: config$(PSEP)%.ico
	$(COPY) $< $@

$(GMAP_DIR)$(PSEP2)%.bmp: config$(PSEP)%.bmp
	$(COPY) $< $@

install: $(INSTALLER_DEPS)
	$(MKNSIS) $(GMAP_DIR)$(PSEP)$(MAPNAME).nsi

zip:
ifeq ($(OUTPUT_DIR),)
$(error MKG_OUTPUT_DIR env variable is not set!)
endif
	$(DEL) "$(OUTPUT_DIR)$(PSEP)$(ZIPNAME)"
	$(ZIP) $(ZIPARGS) "$(OUTPUT_DIR)$(PSEP)$(ZIPNAME)" "$(GMAP_DIR)$(PSEP)7*.img" "$(GMAP_DIR)$(PSEP)$(MAPNAME).img" \
	"$(GMAP_DIR)$(PSEP)$(MAPNAME)_mdr.img" "$(GMAP_DIR)$(PSEP)*.mdx" "$(GMAP_DIR)$(PSEP)*.tdb" "$(GMAP_DIR)$(PSEP)*.typ"


stage1: refresh merge tiles
	@echo Stage-1 completed successfully

stage2: map nsi-script install
	@echo Stage-2 completed successfully

all: refresh merge tiles map nsi-scrpt install
	@echo Map making completed successfully

push:
ifeq ($(MAPSOURCE_DIR),)
	$(warning MKG_MAPSOURCE_DIR env variable is not set!!)
endif
	$(COPY) $(GMAP_DIR)$(PSEP)7*.img $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)$(PSEP)$(MAPNAME).img $(MAPSOURCE_DIR)
	$(COPY) $(GMAP_DIR)$(PSEP)*_mdr.img $(MAPSOURCE_DIR)	
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
	$(DEL) $(OSM_CACHE_DIR)$(PSEP)*.pbf
	$(DEL) $(OSM_CACHE_DIR)$(PSEP)*.osm

	
cleanbounds:
	$(DEL) $(BOUNDS_DIR)$(PSEP)*


cleanoutput:
	$(DEL) $(OUTPUT_DIR)$(PSEP)$(MAP)_map.zip


test:
	@echo $(PRECOMP_SEA_OPTION)


