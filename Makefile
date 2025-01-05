	#######################################################
# OpenHikingMap
#
# Map building automation
#
# Copyright (c) 2021-2024 OpenHiking contributors
# SPDX-License-Identifier: GPL-3.0-only
#
########################################################


##############################################
# Builder configuratios
CONFIG_DIR=config
BOUNDARY_DIR=boundaries
STYLES_DIR=styles
TYP_DIR=typ


##############################################
# Map configurations

include $(CONFIG_DIR)/environment.mk

ifeq ($(MAP),)
$(error MAP variable must be set)
endif

include $(CONFIG_DIR)/$(MAP).cfg

##############################################
# Builder configuratios

TILES_SOURCE?=$(MAP)
HILL_SHADING?=alos
CODE_PAGE?=1250
TYP_BASE?=ohm


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

DEM_SOURCE_TILES=$(shell $(DEMMGR) -s -i -p $(BOUNDARY_POLYGON_FP) -d $(DEM_DIR) $(DEM_SOURCES))

ifeq ($(CONTOUR_LINE_STEP),10)
	CONTOUR_LINE_MEDIUM=20
	CONTOUR_LINE_MAJOR=100
else ifeq ($(CONTOUR_LINE_STEP),20)
	CONTOUR_LINE_MEDIUM=40
	CONTOUR_LINE_MAJOR=200
endif


##############################################
# OSM Data Acquisition

GEOFABRIK_URL_EUROPE=http://download.geofabrik.de/europe/
GEOFABRIK_URL_ASIA=https://download.geofabrik.de/asia/
GEOFABRIK_URL_GLOBAL=https://download.geofabrik.de/

OSM_COUNTRIES_EUROPE?=$(OSM_COUNTRY_LIST)

OSM_COUNTRIES_EUROPE_FP := $(foreach ds,$(OSM_COUNTRIES_EUROPE),$(OSM_CACHE_DIR)$(PSEP)$(ds)-latest.osm.pbf)
OSM_COUNTRIES_ASIA_FP := $(foreach ds,$(OSM_COUNTRIES_ASIA),$(OSM_CACHE_DIR)$(PSEP)$(ds)-latest.osm.pbf)
OSM_COUNTRIES_GLOBAL_FP := $(foreach ds,$(OSM_COUNTRIES_GLOBAL),$(OSM_CACHE_DIR)$(PSEP)$(ds)-latest.osm.pbf)

OSM_COUNTRIES_ALL = $(OSM_COUNTRIES_EUROPE) $(OSM_COUNTRIES_ASIA) $(OSM_COUNTRIES_GLOBAL)

MAP_OSM_LATEST_PBF = $(OSM_COUNTRIES_EUROPE_FP) $(OSM_COUNTRIES_ASIA_FP) $(OSM_COUNTRIES_GLOBAL_FP)

##############################################
# Preprocessing

TILES_DIR=$(WORKING_DIR)$(PSEP)tiles-$(TILES_SOURCE)
BOUNDARY_POLYGON_FP=$(BOUNDARY_DIR)$(PSEP)$(BOUNDARY_POLYGON)

PREFILTER_CONDITION?="building=residential building=apartments building=detached building=house building=garage building=garages natural=tree_row"


ifeq ($(PREFILTERING),yes)
	MAP_INP_OSM_O5M := $(foreach ds,$(OSM_COUNTRIES_ALL),$(TILES_DIR)$(PSEP)$(ds)-flt.o5m)
	MAP_PREFILTER_OUTPUT_O5M := $(foreach ds,$(OSM_COUNTRIES_ALL),$(TILES_DIR)$(PSEP)$(ds)-flt.o5m)
else
	MAP_INP_OSM_O5M := $(foreach ds,$(OSM_COUNTRIES_ALL),$(TILES_DIR)$(PSEP)$(ds)-clipped.o5m)
	MAP_PREFILTER_OUTPUT_O5M := $(foreach ds,$(OSM_COUNTRIES_ALL),$(TILES_DIR)$(PSEP)$(ds)-clipped.o5m)
endif


##############################################
# Route processing

MAP_SYMBOL_PRIORITY_FILE=$(CONFIG_DIR)$(PSEP)symbol-priorities.csv
MAP_SYMBOL_LOOKUP_FILE=$(CONFIG_DIR)$(PSEP)symbol-lookup.csv

MAP_COUNTRY_ROUTES_O5M := $(foreach ds,$(OSM_COUNTRIES_ALL),$(TILES_DIR)$(PSEP)$(ds)-routes.o5m)
MAP_ROUTES_FILE=routes
MAP_ROUTES_PBF_FP=$(TILES_DIR)$(PSEP)$(MAP_ROUTES_FILE).pbf
ROUTE_CONDITION?="route=hiking or route=foot or ( route=piste and piste:type=nordic ) or ( route=ski and piste:type=nordic )"

MAP_HIKING_SYMBOLS_OSM_FP=$(TILES_DIR)$(PSEP)symbols.osm

ifeq ($(GENERATE_HIKING_SYMBOLS),yes)
	MAP_INP_SYMBOLS_OSM=$(MAP_HIKING_SYMBOLS_OSM_FP)
endif

SYMBOLS_START_ID=120000000000


##############################################
# Merging

MAP_INP_OSM_PBF := $(foreach ds,$(OSM_COUNTRIES_ALL),$(TILES_DIR)$(PSEP)$(ds)-clipped.pbf)
MAP_INP_OSM_PBF_ARGS=$(foreach wrd,$(MAP_INP_OSM_PBF),--read-pbf file=$(wrd))


MAP_INP_SUPP := $(foreach ds,$(SUPPLEMENTARY_DATA),$(OSM_CACHE_DIR)$(PSEP)$(ds))
MAP_INP_SUPP_PBF := $(foreach ds,$(SUPPLEMENTARY_DATA),$(OSM_CACHE_DIR)$(PSEP)$(ds))
MAP_INP_SUPP_PBF_ARGS=$(foreach wrd,$(OHM_INP_SUPP_PBF),--read-pbf file=$(wrd))

ifneq ($(CONTOUR_LINES),)
MAP_INP_CONTOUR=$(CONTOUR_DIR)$(PSEP)$(CONTOUR_LINES)
else
MAP_INP_CONTOUR=
endif

MAP_INP_CONTOUR_ARGS=--read-pbf file=$(MAP_INP_CONTOUR)

MAP_MERGED_PBF=master$(MAP).pbf
MAP_MERGED_O5M=master$(MAP).o5m
MAP_MERGED_PBF_FP=$(TILES_DIR)$(PSEP)$(MAP_MERGED_PBF)
MAP_MERGED_O5M_FP=$(TILES_DIR)$(PSEP)$(MAP_MERGED_O5M)


##############################################
# Residential naming

PLACE_CONDITION?="place= or landuse=residential"

ifeq ($(PREFILTERING),yes)
	MAP_NAMING_INP_O5M := $(TILES_DIR)$(PSEP)%-flt.o5m
else
	MAP_NAMING_INP_O5M := $(TILES_DIR)$(PSEP)%-clipped.o5m
endif

MAP_INP_OSC := $(foreach ds,$(OSM_COUNTRIES_ALL),$(TILES_DIR)$(PSEP)$(ds)-places.osc)

MAP_MERGED_NAMED_PBF=master$(MAP)-named.pbf
MAP_MERGED_NAMED_PBF_FP=$(TILES_DIR)$(PSEP)$(MAP_MERGED_NAMED_PBF)


##############################################
# Bounds Generation

BOUNDS_DIR?=$(BOUNDS_CACHE_DIR)$(PSEP)bounds-$(TILES_SOURCE)
MAP_BOUNDS_O5M=bounds.o5m
MAP_BOUNDS_O5M_FP=$(TILES_DIR)$(PSEP)$(MAP_BOUNDS_O5M)

BOUNDS_ADMIN_CONDITION?="boundary=administrative and ( admin_level=2 or admin_level=8 or admin_level=9 )"

MAP_BOUNDS_TEMP1_O5M=bounds-temp1.o5m
MAP_BOUNDS_TEMP1_O5M_FP=$(TILES_DIR)$(PSEP)$(MAP_BOUNDS_TEMP1_O5M)
MAP_BOUNDS_TEMP2_O5M=bounds-temp2.o5m
MAP_BOUNDS_TEMP2_O5M_FP=$(TILES_DIR)$(PSEP)$(MAP_BOUNDS_TEMP2_O5M)
MAP_BOUNDS_TEMP3_O5M=bounds-temp3.o5m
MAP_BOUNDS_TEMP3_O5M_FP=$(TILES_DIR)$(PSEP)$(MAP_BOUNDS_TEMP3_O5M)
POSTAL_CODES=2026 2099 2407 2453 2485 2508 2509 2660 2835 2879 2903 2921 3065 3078 3082 3147 3221 3232 3233 3234 3508 3517 3518 3519 3521 3558 3603 3604 3621 3625 3651 3661 3662 3902 3923 3944 3945 3988 4014 4063 4067 4074 4078 4079 4085 4086 4162 4224 4225 4246 4252 4253 4432 4433 4446 4447 4486 4551 4803 4804 5008 5152 5212 5349 5358 5359 5449 5461 5623 5664 5671 5711 5752 6008 6044 6062 6648 6710 6757 6771 6791 6806 7018 7019 7027 7187 7385 7386 7451 7557 7691 7693 7714 7715 8019 8054 8103 8184 8257 8297 8411 8412 8447 8448 8451 8511 8531 8591 8598 8691 8789 8795 8966 9011 9012 9019 9098 9183 9242 9339 9407 9408 9433 9434 9438 9494 9541 9608 9609 9740 9955 9981
BOUNDS_POSTAL_CONDITION="( boundary=postal_code and ( first
BOUNDS_POSTAL_CONDITION+=$(foreach POSTAL_CODE,$(POSTAL_CODES),or postal_code=$(POSTAL_CODE))
BOUNDS_POSTAL_CONDITION:=$(subst first or ,,$(BOUNDS_POSTAL_CONDITION))
BOUNDS_POSTAL_CONDITION+=) ) or ( boundary=administrative and (  admin_level=2 or admin_level=8 or admin_level=9 ) )"


##############################################
# Tile Splitting

ifeq ($(ADD_RESIDENTIAL_NAMES),yes)
	MAP_SPLITTER_INP_PBF=$(MAP_MERGED_NAMED_PBF_FP)
else
	MAP_SPLITTER_INP_PBF=$(MAP_MERGED_PBF_FP)
endif

TILE_ARGS=$(TILES_DIR)$(PSEP)template.args
SPLITTER_MEMORY?=5000M
SPLITTER_MAX_NODES?=1800000
SPLITTER_MAX_AREAS?=255
SPLITTER_STATUS_FREQ?=120

##############################################
# Garmin map generation

GMAP_DIR=$(WORKING_DIR)$(PSEP)gmap-$(MAP)
MKGMAP_JOBS?=2
MKGMAP_MEMORY?=4192M
DRAW_PRIORITY?=16
PRODUCT_VERSION?=100

ifeq ($(LINUX),0)
GMAP_DRIVE=$(word 1,$(subst :, ,$(GMAP_DIR))):
endif


OHM_ARGS_TEMPLATE=$(CONFIG_DIR)$(PSEP)mkgmap.args


ifeq ($(TYP_FILE),)
	TYP_BASENAME=$(TYP_BASE)$(MAP)
	TYP_FILE=$(TYP_BASENAME).typ
endif

TYP_FILE_FP=$(GMAP_DIR)$(PSEP)$(TYP_FILE)

STYLES=info lines options points polygons relations version

MERGED_ARGS=$(TILES_DIR)$(PSEP)mkgmap.args
STYLES_RP := $(foreach wrd,$(STYLES),$(STYLES_DIR)$(PSEP)$(wrd))

ifneq ($(HILL_SHADING),)
      HILL_SHADING_DIR=$(DEM_DIR)$(PSEP)$(HILL_SHADING)
endif

ifeq ($(GENERATE_SEA),yes)
#	GEN_SEA_OPTIONS=--generate-sea=extend-sea-sectors,close-gaps=500,land-tag=natural=land
	PRECOMP_SEA_OPTION=--precomp-sea=$(SEA_AREA_DIR)
else
#	GEN_SEA_OPTIONS=
endif
	
ifneq ($(BOUNDS_BASE),)
	BOUNDS_OPTS=--bounds="$(BOUNDS_DIR)"
else
	BOUNDS_OPTS=
endif


ifeq ($(USE_LOWERCASE),yes)
	LOWER_CASE=--lower-case
else
	LOWER_CASE=
endif

ifeq ($(TRANSPARENT),yes)
	TRANSPARENCY_OPT=--transparent
else
	TRANSPARENCY_OPT=
endif

ifeq ($(CYCLE_MAP),yes)
	CYCLE_MAP_OPT=--cycle-map
endif

ifneq ($(NEARBY_POI_CFG_FILE),)
	NEARBY_POI_CFG_OPT=--nearby-poi-rules-config=$(CONFIG_DIR)$(PSEP)$(NEARBY_POI_CFG_FILE)
endif

ifneq ($(ROAD_NAME_CFG_FILE),)
	ROAD_NAME_CFG_OPT=--road-name-config=$(CONFIG_DIR)$(PSEP)$(ROAD_NAME_CFG_FILE)
endif

ifeq ($(GMAPSUPP),yes)
	GMAPSUPP_OPTION=--gmapsupp
endif

ifeq ($(GMAPI),yes)
	GMAPI_OPTION=--gmapi
endif

ifneq ($(MAP_REGION),)
	MAP_REGION_SOPT=REGION=$(MAP_REGION)
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

ifeq ($(GMAPI),yes)
	MAKE_GMAPI=gmapi
endif


IMG_ZIP_NAME?=$(MAPNAME).zip

FAMILY_NAME_STRIPPED:=$(subst ",$(empty),$(FAMILY_NAME))
GMAPI_DIR_NAME=$(FAMILY_NAME_STRIPPED).gmap
GMAPI_ZIP_NAME?=$(subst $(space),$(empty),$(FAMILY_NAME_STRIPPED)).zip



##############################################
# Recipes

.PHONY: refresh symbols merge bounds tiles map typ install zip clean cleanall cleancache 

alos:
	$(DEMMGR) -r --poly=$(BOUNDARY_POLYGON_FP) --dem=$(DEM_DIR) --alos=$(ALOS_DOWNLOAD_SUBDIR)

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


$(OSM_COUNTRIES_EUROPE_FP): GEOFABRIK_URL = $(GEOFABRIK_URL_EUROPE)
$(OSM_COUNTRIES_ASIA_FP): GEOFABRIK_URL = $(GEOFABRIK_URL_ASIA)
$(OSM_COUNTRIES_GLOBAL_FP): GEOFABRIK_URL = $(GEOFABRIK_URL_GLOBAL)
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
	$(ROUTEMAPPER) --start-node-id=$(SYMBOLS_START_ID) --prio=$(MAP_SYMBOL_PRIORITY_FILE) --lookup=$(MAP_SYMBOL_LOOKUP_FILE) --pictogram=$(MAP_HIKING_SYMBOLS_OSM_FP) $(MAP_ROUTES_PBF_FP)


symbols: $(MAP_HIKING_SYMBOLS_OSM_FP)
	@echo "Done"


$(MAP_MERGED_PBF_FP):  $(MAP_INP_OSM_O5M) $(MAP_INP_SYMBOLS_OSM) $(MAP_INP_SUPP) $(MAP_INP_CONTOUR)
	$(OSMCONVERT) --hash-memory=240-30-2  $^ -B=$(BOUNDARY_POLYGON_FP) -o=$@


merge: $(MAP_MERGED_PBF_FP)
	@echo "Merge completed"
	
$(TILES_DIR)$(PSEP2)%-places.o5m: $(TILES_DIR)$(PSEP)%-clipped.o5m
	$(OSMFILTER) $< --keep=$(PLACE_CONDITION)  -o=$@

$(TILES_DIR)$(PSEP2)%-places.pbf: $(TILES_DIR)$(PSEP)%-places.o5m
	$(OSMCONVERT) $< -o=$@

$(TILES_DIR)$(PSEP2)%-places.osc: $(TILES_DIR)$(PSEP)%-places.pbf
	$(MAKENAMES) $^ $@


$(MAP_MERGED_NAMED_PBF_FP): $(MAP_MERGED_PBF_FP) $(MAP_INP_OSC)
	$(OSMCONVERT) --hash-memory=240-30-2   --drop-version $^ -o=$@

places: $(MAP_INP_OSC)
	@echo "DONE"

merge-osmosis:  $(MAP_INP_OSM_PBF) $(MAP_INP_SUPP_PBF) $(MAP_INP_CONTOUR)
	$(OSMOSIS) $(MAP_INP_OSM_PBF_ARGS) $(MAP_INP_SUPP_PBF_ARGS) $(MAP_INP_CONTOUR_ARGS) --merge --bp file=$(BOUNDARY_POLYGON_FP) --wb file=$@
	@echo "Merge completed"

$(MAP_MERGED_O5M_FP): $(MAP_MERGED_PBF_FP)
	$(OSMCONVERT) $^ -o=$@

$(MAP_BOUNDS_TEMP1_O5M_FP): $(MAP_MERGED_O5M_FP)
	$(OSMFILTER) $< --keep-nodes= --keep-ways-relations=$(BOUNDS_POSTAL_CONDITION) -o=$@

$(MAP_BOUNDS_TEMP2_O5M_FP): $(MAP_BOUNDS_TEMP1_O5M_FP)
	$(OSMFILTER) $< --modify-relation-tags="boundary=postal_code add admin_level=10" -o=$@

$(MAP_BOUNDS_TEMP3_O5M_FP): $(MAP_BOUNDS_TEMP2_O5M_FP)
	$(OSMFILTER) $< --modify-relation-tags="boundary=postal_code to boundary=administrative" -o=$@


ifeq ($(BOUNDS_BASE),admin)
$(MAP_BOUNDS_O5M_FP): $(MAP_MERGED_O5M_FP)
	$(OSMFILTER) $< --keep-nodes= --keep-ways-relations=$(BOUNDS_ADMIN_CONDITION)  -o=$@
else
$(MAP_BOUNDS_O5M_FP): $(MAP_BOUNDS_TEMP3_O5M_FP)
	$(OSMFILTER) $< --modify-relation-tags="name:hu= to name=" -o=$@
endif


bounds: $(MAP_BOUNDS_O5M_FP)
	java -cp $(MKGMAP) uk.me.parabola.mkgmap.reader.osm.boundary.BoundaryPreprocessor "$<" "$(BOUNDS_DIR)"
	@echo "Bounds created"

tiles: $(MAP_SPLITTER_INP_PBF)
	java -Xmx$(SPLITTER_MEMORY) -ea -jar $(SPLITTER) --mapid=$(GARMIN_SEGMENT_ID)  --max-nodes=$(SPLITTER_MAX_NODES) --max-areas=$(SPLITTER_MAX_AREAS) \
	--status-freq=$(SPLITTER_STATUS_FREQ) $(SPLITTER_THREADS) $< --output-dir=$(TILES_DIR)


$(MERGED_ARGS): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS)
ifeq ($(LINUX),1)
	$(COPY) $(OHM_ARGS_TEMPLATE) $(MERGED_ARGS)
	$(CAT)  $(TILE_ARGS) >> $(MERGED_ARGS)
else
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS) $(MERGED_ARGS)
endif


ifeq ($(TYP_COMPILE),yes)
$(TYP_FILE_FP): $(TYP_DIR)$(PSEP)$(TYP_BASE).txt
	$(COPY) $< $(GMAP_DIR)$(PSEP)$(TYP_BASENAME).txt	
ifeq ($(LINUX),1)
	cd $(GMAP_DIR) && java -Xmx1024M -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYP_BASENAME).txt --output-dir=$(GMAP_DIR)
else
	$(GMAP_DRIVE) & cd $(GMAP_DIR) & java -Xmx1024M -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYP_BASENAME).txt --output-dir=$(GMAP_DIR)
endif
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.img
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.tdb

else

$(TYP_FILE_FP): $(TYP_DIR)$(PSEP)$(TYP_FILE)
	$(COPY) $< $(GMAP_DIR)
endif

$(GMAP_DIR)$(PSEP)$(TYP_BASE)%.typ: $(TYP_DIR)$(PSEP)$(TYP_BASE).txt
	$(COPY) $< $(GMAP_DIR)$(PSEP)$(TYP_BASENAME).txt
ifeq ($(LINUX),1)
	cd $(GMAP_DIR) && java -Xmx1024M -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYP_BASENAME).txt --output-dir=$(GMAP_DIR)
else
	$(GMAP_DRIVE) & cd $(GMAP_DIR) & java -Xmx1024M -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --code-page=$(CODE_PAGE) $(TYP_BASENAME).txt --output-dir=$(GMAP_DIR)
endif
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.img
	$(DEL) $(GMAP_DIR)$(PSEP)osmmap.tdb


typ: $(TYP_FILE_FP)
	@echo "Completed"

map:  $(MERGED_ARGS) $(TYP_FILE_FP)
	java -Xmx$(MKGMAP_MEMORY) -ea -jar $(MKGMAP) --mapname=$(GARMIN_MAP_ID) \
	--family-id=$(FAMILY_ID) --family-name=$(FAMILY_NAME) --product-id=1 --product-version=$(PRODUCT_VERSION) \
	--series-name=$(SERIES_NAME) --overview-mapname=$(MAPNAME) --description:$(MAPNAME) \
	 $(TYP_FILE_FP) --dem=$(HILL_SHADING_DIR) --dem-poly=$(BOUNDARY_POLYGON_FP) --draw-priority=$(DRAW_PRIORITY) \
	 --code-page=$(CODE_PAGE)  $(NEARBY_POI_CFG_OPT) $(ROAD_NAME_CFG_OPT) \
	 $(PRECOMP_SEA_OPTION) $(LOWER_CASE) $(TRANSPARENCY_OPT) $(CYCLE_MAP_OPT) $(BOUNDS_OPTS) \
	 --style-file=$(STYLES_DIR) --style="$(MAP_STYLE)" --style-option="CODE_PAGE=$(CODE_PAGE);$(MAP_REGION_SOPT)" \
	 $(LICENSE_OPTION) $(COPYRIGHT_OPTION) $(GMAPSUPP_OPTION) $(GMAPI_OPTION) \
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
	$(DEL) "$(OUTPUT_DIR)$(PSEP)$(IMG_ZIP_NAME)"
	$(ZIP) $(ZIPARGS) "$(OUTPUT_DIR)$(PSEP)$(IMG_ZIP_NAME)" "$(GMAP_DIR)$(PSEP)7*.img" "$(GMAP_DIR)$(PSEP)$(MAPNAME).img" \
	"$(GMAP_DIR)$(PSEP)$(MAPNAME)_mdr.img" "$(GMAP_DIR)$(PSEP)*.mdx" "$(GMAP_DIR)$(PSEP)*.tdb" "$(GMAP_DIR)$(PSEP)*.typ"


gmapi:
ifeq ($(LINUX),1)
	cd $(GMAP_DIR) && $(ZIP) $(ZIPARGS) $(GMAPI_ZIP_NAME) '$(GMAPI_DIR_NAME)'
else
	$(GMAP_DRIVE) & cd $(GMAP_DIR) & $(ZIP) $(ZIPARGS) $(GMAPI_ZIP_NAME) "$(GMAPI_DIR_NAME)"
endif


stage1: refresh merge tiles
	@echo Stage-1 completed successfully

stage2: map nsi-script install $(MAKE_GMAPI)
	@echo Stage-2 completed successfully

all: refresh merge tiles map nsi-script install $(MAKE_GMAPI)
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
ifeq ($(LINUX),0)
ifeq ($(GMAPI),yes)
	$(RMDIR) "$(GMAP_DIR)$(PSEP)$(GMAPI_DIR_NAME)"
endif
endif
	$(DEL) $(GMAP_DIR)$(PSEP)*

cleanall:
ifeq ($(LINUX),0)
ifeq ($(GMAPI),yes)
	$(RMDIR) "$(GMAP_DIR)$(PSEP)$(GMAPI_DIR_NAME)"
endif
endif
	$(DEL) $(TILES_DIR)$(PSEP)*
	$(DEL) $(GMAP_DIR)$(PSEP)*

cleancache:
	$(DEL) $(OSM_CACHE_DIR)$(PSEP)*.pbf

cleanbounds:
	$(DEL) $(BOUNDS_DIR)$(PSEP)*


cleanoutput:
	$(DEL) $(OUTPUT_DIR)$(PSEP)$(MAP)_map.zip


test:
	@echo $(MAKESYMBOLS)
	@echo $(MKG_ROUTEMAPPER)





