
# Tools
OSMCONVERT=osmconvert64.exe
SPLITTER=c:\Apps\splitter\splitter.jar
MKGMAP=c:\Apps\mkgmap-4819\mkgmap.jar
#MKGMAP=c:\Apps\mkgmap-3498\mkgmap.jar
MKNSIS="c:\Program Files (x86)\NSIS\Bin\makensis.exe"
WGET=wget
COPY=copy /b
MOVE=move
DEL=del

# Builder directories
CONFIG_DIR=config
STYLES_DIR=styles

# External data sources
GEOFABRIK_URL=http://download.geofabrik.de/europe/
OSM_DS_LIST=hungary-latest

TJEL_URL=https://data2.openstreetmap.hu/
TJEL_NAME=vjel.osm

# Local data caches
DATASET_DIR=c:\Dataset\map
OSM_CACHE_DIR=$(DATASET_DIR)\osm
CONTOUR_DIR=$(DATASET_DIR)\contour
TJEL_CACHE_DIR=$(DATASET_DIR)\jelek
DEM_DIR=$(DATASET_DIR)\dem


CONTOUR_DS_LIST=contour-hungary.o5m

# Dataset merging
BOUNDARY_POLYGON=$(CONFIG_DIR)\hungary.poly

OSM_O5M_LIST := $(foreach ds,$(OSM_DS_LIST),$(OSM_CACHE_DIR)\$(ds).o5m)
CONTOUR_O5M_LIST := $(foreach ds,$(CONTOUR_DS_LIST),$(CONTOUR_DIR)\$(ds))
TJEL_CACHED := $(TJEL_CACHE_DIR)\$(TJEL_NAME)

MERGED_PBF_NAME=openhiking.pbf
MERGED_PBF=$(OSM_CACHE_DIR)\$(MERGED_PBF_NAME)

# Tile splitting
TILES_DIR=$(DATASET_DIR)\tiles
TILE_ARGS=$(TILES_DIR)\template.args

# Garmin map generation
GMAP_DIR=c:\Dataset\gmap
OHM_ARGS_TEMPLATE=$(CONFIG_DIR)\ohm-template.args
TYP_FILE=$(CONFIG_DIR)\ohm.typ
STYLE_NAME=hiking
STYLES=info lines options points polygons relations version

MERGED_ARGS=$(TILES_DIR)\openhiking.args
STYLES2 := $(foreach wrd,$(STYLES),$(STYLES_DIR)\$(STYLE_NAME)\$(wrd))

MDX_FILE=$(GMAP_DIR)\openhiking.mdx

refresh:
	$(DEL)  $(OSM_CACHE_DIR)\*.o5m
	$(MOVE) $(OSM_CACHE_DIR)\$(OSM_DS_LIST).osm.pbf $(OSM_CACHE_DIR)\$(OSM_DS_LIST).osm.pbf.bkp
	$(WGET) $(GEOFABRIK_URL)$(OSM_DS_LIST).osm.pbf -P $(OSM_CACHE_DIR)
	$(MOVE) $(TJEL_CACHE_DIR)\$(TJEL_NAME) $(TJEL_CACHE_DIR)\$(TJEL_NAME).bkp
	$(WGET) $(TJEL_URL)$(TJEL_NAME) -P $(TJEL_CACHE_DIR)

$(OSM_CACHE_DIR)\\%.o5m: $(OSM_CACHE_DIR)\\%.osm.pbf
	$(OSMCONVERT) $< -o=$@

$(MERGED_PBF): $(OSM_O5M_LIST)
	$(OSMCONVERT) $(OSM_O5M_LIST) $(CONTOUR_O5M_LIST) $(TJEL_CACHED) -B=$(BOUNDARY_POLYGON) -o=$(MERGED_PBF)

tiles: $(MERGED_PBF)
	java -Xmx4192M -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $(MERGED_PBF) --output-dir=$(TILES_DIR)

$(MERGED_ARGS): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS) $(MERGED_ARGS)

$(MDX_FILE): $(STYLES2) $(MERGED_ARGS)
	java -Xmx4192M -ea -jar $(MKGMAP) --mapname=71221559 --family-id=3690 $(TYP_FILE) --dem=$(DEM_DIR) --dem-poly=$(BOUNDARY_POLYGON) \
	--style-file=$(STYLES_DIR)\ --output-dir=$(GMAP_DIR) -c $(MERGED_ARGS) --max-jobs=2

map: $(MDX_FILE)
	@echo "Completed"

install:
	$(COPY) $(CONFIG_DIR)\icon.ico $(GMAP_DIR)
	$(COPY) $(TYP_FILE) $(GMAP_DIR)
	$(MKNSIS) $(GMAP_DIR)\openhiking.nsi

clean:
	$(DEL) $(GMAP_DIR)\*

cleanall:
	$(DEL) $(MERGED_PBF)
	$(DEL) $(TILES_DIR)\*
	$(DEL) $(GMAP_DIR)\*
