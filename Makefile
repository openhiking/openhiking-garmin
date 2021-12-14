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
DEM_DIR=$(HGT_DIR)\VIEW3
OSM_CACHE_DIR=$(DATASET_DIR)\osm
CONTOUR_DIR=$(DATASET_DIR)\contour
TJEL_CACHE_DIR=$(DATASET_DIR)\jelek


##############################################
# Map configuration

OSM_COUNTRIES_CE=hungary slovakia czech-republic poland austria italy slovenia croatia bosnia-herzegovina serbia romania ukraine
OSM_COUNTRIES_HU=hungary
OSM_COUNTRIES_EXP=italy slovenia austria

BOUNDARY_DIR=boundaries
BOUNDARY_POLYGON_CE=$(BOUNDARY_DIR)\central-europe.poly
BOUNDARY_POLYGON_HU=$(BOUNDARY_DIR)\hungary.poly
BOUNDARY_POLYGON_EXP=$(BOUNDARY_DIR)\austria.poly


##############################################
# Builder configuration
CONFIG_DIR=config
STYLES_DIR=styles


##############################################
# Contour Lines

CONTOUR_START_ID=100000000000

CONTOUR_FILE_PFX=$(CONTOUR_DIR)\contour-

CONTOUR_CE=contour-ce-20.o5m
CONTOUR_HU=contour-hungary-10.o5m
CONTOUR_EXP=contour-ce-20.o5m

##############################################
# Dataset Preparation

OHM_INP_OSM_CE := $(foreach ds,$(OSM_COUNTRIES_CE),$(OSM_CACHE_DIR)\$(ds).o5m)
OHM_INP_OSM_HU := $(foreach ds,$(OSM_COUNTRIES_HU),$(OSM_CACHE_DIR)\$(ds).o5m)
OHM_INP_OSM_EXP := $(foreach ds,$(OSM_COUNTRIES_EXP),$(OSM_CACHE_DIR)\$(ds).o5m)

OHM_INP_CONTOUR_CE=$(CONTOUR_DIR)\$(CONTOUR_CE)
OHM_INP_CONTOUR_HU=$(CONTOUR_DIR)\$(CONTOUR_HU)
OHM_INP_CONTOUR_EXP=$(CONTOUR_DIR)\$(CONTOUR_EXP)

OHM_INP_JEL= $(TJEL_CACHE_DIR)\$(TJEL_NAME)

OHM_OUT_PBF_CE=openhiking-ce.pbf
OHM_OUT_PBF_HU=openhiking-hu.pbf
OHM_OUT_PBF_EXP=openhiking-exp.pbf

OHM_OUT_PBF_CE_FP=$(OSM_CACHE_DIR)\$(OHM_OUT_PBF_CE)
OHM_OUT_PBF_HU_FP=$(OSM_CACHE_DIR)\$(OHM_OUT_PBF_HU)
OHM_OUT_PBF_EXP_FP=$(OSM_CACHE_DIR)\$(OHM_OUT_PBF_EXP)


##############################################
# Tile Splitting

TILES_DIR_CE=$(DATASET_DIR)\tiles-ce
TILE_ARGS_CE=$(TILES_DIR_CE)\template.args

TILES_DIR_HU=$(DATASET_DIR)\tiles-hu
TILE_ARGS_HU=$(TILES_DIR_HU)\template.args

TILES_DIR_EXP=$(DATASET_DIR)\tiles-exp
TILE_ARGS_EXP=$(TILES_DIR_EXP)\template.args

##############################################
# Garmin map generation

GMAP_DIR_CE=c:\Dataset\gmap-ce
GMAP_DIR_HU=c:\Dataset\gmap-hu
GMAP_DIR_EXP=c:\Dataset\gmap-exp

OHM_ARGS_TEMPLATE=$(CONFIG_DIR)\ohm-template.args
TYP_FILE_CE=$(CONFIG_DIR)\ohmce.typ
TYP_FILE_HU=$(CONFIG_DIR)\ohmhu.typ
TYP_FILE_EXP=$(CONFIG_DIR)\ohmexp.typ

STYLE_NAME=hiking
STYLES=info lines options points polygons relations version

MERGED_ARGS_CE=$(TILES_DIR_CE)\openhiking.args
MERGED_ARGS_HU=$(TILES_DIR_HU)\openhiking.args
MERGED_ARGS_EXP=$(TILES_DIR_EXP)\openhiking.args

STYLES2 := $(foreach wrd,$(STYLES),$(STYLES_DIR)\$(STYLE_NAME)\$(wrd))

ce-contour:
	$(PHYGHTMAP) --jobs=2 --viewfinder-mask=3 -s 10 -c 100,20 --polygon=$(BOUNDARY_POLYGON_CE) --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) --hgtdir=$(HGT_DIR) \
	--max-nodes-per-tile=0 --o5m -o $(CONTOUR_FILE_PFX)ce

hu-contour:
	$(PHYGHTMAP) --jobs=2 --viewfinder-mask=3 -s 10 -c 100,20 --polygon=$(BOUNDARY_POLYGON_HU) --start-node-id=$(CONTOUR_START_ID) --start-way-id=$(CONTOUR_START_ID) --hgtdir=$(HGT_DIR) \
	--max-nodes-per-tile=0 --o5m -o $(CONTOUR_FILE_PFX)hu

$(OSM_CACHE_DIR)\\%-latest.osm.pbf:
	$(WGET) $(GEOFABRIK_URL)$*-latest.osm.pbf -P $(OSM_CACHE_DIR)

$(TJEL_CACHED):
	$(WGET) $(TJEL_URL)$(TJEL_NAME) -P $(TJEL_CACHE_DIR)

refresh: $(OHM_INP_OSM_CE) $(OHM_INP_OSM_HU) $(OHM_INP_OSM_EXP) $(TJEL_CACHED)
	@echo "Completed"

$(OSM_CACHE_DIR)\\%.o5m: $(OSM_CACHE_DIR)\%-latest.osm.pbf
	$(OSMCONVERT) $< -B=$(BOUNDARY_POLYGON_CE) -o=$@

$(OHM_OUT_PBF_CE_FP):  $(OHM_INP_OSM_CE) $(OHM_INP_CONTOUR_CE) $(OHM_INP_JEL)
	$(OSMCONVERT) $(OHM_INP_OSM_CE) $(OHM_INP_CONTOUR_CE) $(OHM_INP_JEL) -o=$@

$(OHM_OUT_PBF_HU_FP): $(OHM_INP_OSM_HU) $(OHM_INP_CONTOUR_HU) $(OHM_INP_JEL)
	$(OSMCONVERT) $(OHM_INP_OSM_HU) $(OHM_INP_CONTOUR_HU) $(OHM_INP_JEL) -B=$(BOUNDARY_POLYGON_HU) -o=$@

$(OHM_OUT_PBF_EXP_FP): $(OHM_INP_OSM_EXP) $(OHM_INP_CONTOUR_EXP)
	$(OSMCONVERT) $(OHM_INP_OSM_EXP) $(OHM_INP_CONTOUR_EXP) -B=$(BOUNDARY_POLYGON_EXP) -o=$@

ce-tiles: $(OHM_OUT_PBF_CE_FP)
	java -Xmx4192M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR_CE)

hu-tiles: $(OHM_OUT_PBF_HU_FP)
	java -Xmx4192M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR_HU)

exp-tiles: $(OHM_OUT_PBF_EXP_FP)
	java -Xmx4192M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $< --output-dir=$(TILES_DIR_EXP)


$(MERGED_ARGS_CE): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS_CE)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS_CE) $(MERGED_ARGS_CE)

$(MERGED_ARGS_HU): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS_HU)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS_HU) $(MERGED_ARGS_HU)

$(MERGED_ARGS_EXP): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS_EXP)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS_EXP) $(MERGED_ARGS_EXP)


ce-map:  $(STYLES2) $(MERGED_ARGS_CE)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=3691 --family-name="OpenHiking CE" --series-name="OpenHiking CE" $(TYP_FILE_CE) \
	--dem=$(DEM_DIR) --dem-poly=$(BOUNDARY_POLYGON_CE) --generate-sea=land-tag=natural=land \
	--style-file=$(STYLES_DIR)\ --output-dir=$(GMAP_DIR_CE) -c $(MERGED_ARGS_CE) --max-jobs=2

hu-map:  $(STYLES2) $(MERGED_ARGS_HU)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=71221559 --family-id=3690 --family-name="OpenHiking HU" --series-name="OpenHiking HU" $(TYP_FILE_HU) \
	 --dem=$(DEM_DIR) --dem-poly=$(BOUNDARY_POLYGON_HU) --style-file=$(STYLES_DIR)\ --output-dir=$(GMAP_DIR_HU) -c $(MERGED_ARGS_HU) --max-jobs=2

exp-map:  $(STYLES2) $(MERGED_ARGS_EXP)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=74221559 --family-id=3692 --family-name="OpenHiking EXP" --series-name="OpenHiking EXP" $(TYP_FILE_EXP)   \
	--dem=$(DEM_DIR) --dem-poly=$(BOUNDARY_POLYGON_EXP) --generate-sea=land-tag=natural=land --style-file=$(STYLES_DIR)\ \
	--output-dir=$(GMAP_DIR_EXP) -c $(MERGED_ARGS_EXP) --max-jobs=2

ce-install:
	$(COPY) $(CONFIG_DIR)\icon.ico $(GMAP_DIR_CE)
	$(COPY) $(TYP_FILE_CE) $(GMAP_DIR_CE)
	$(MKNSIS) $(GMAP_DIR_CE)\openhiking.nsi

hu-install:
	$(COPY) $(CONFIG_DIR)\icon.ico $(GMAP_DIR_HU)
	$(COPY) $(TYP_FILE_HU) $(GMAP_DIR_HU)
	$(MKNSIS) $(GMAP_DIR_HU)\openhiking.nsi

exp-install:
	$(COPY) $(CONFIG_DIR)\icon.ico $(GMAP_DIR_EXP)
	$(COPY) $(TYP_FILE_EXP) $(GMAP_DIR_EXP)
	$(MKNSIS) $(GMAP_DIR_EXP)\openhiking.nsi


ce-clean:
	$(DEL) $(GMAP_DIR_CE)\*

hu-clean:
	$(DEL) $(GMAP_DIR_HU)\*

exp-clean:
	$(DEL) $(GMAP_DIR_EXP)\*


ce-cleanall:
	$(DEL) $(OHM_OUT_PBF_CE_FP)
	$(DEL) $(TILES_DIR_CE)\*
	$(DEL) $(GMAP_DIR_CE)\*

hu-cleanall:
	$(DEL) $(OHM_OUT_PBF_HU_FP)
	$(DEL) $(TILES_DIR_HU)\*
	$(DEL) $(GMAP_DIR_HU)\*

exp-cleanall:
	$(DEL) $(OHM_OUT_PBF_EXP_FP)
	$(DEL) $(TILES_DIR_EXP)\*
	$(DEL) $(GMAP_DIR_EXP)\*


cleancache:
	$(DEL)  $(OSM_CACHE_DIR)\*.o5m
	$(DEL)  $(OSM_CACHE_DIR)\*.pbf
