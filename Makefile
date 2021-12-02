
# Tools
OSMOSIS=c:\Apps\osmosis-0-48\bin\osmosis.bat
SPLITTER=c:\Apps\splitter\splitter.jar
MKGMAP=c:\Apps\mkgmap-4819\mkgmap.jar
MKNSIS="c:\Program Files (x86)\NSIS\Bin\makensis.exe"
WGET=wget
COPY=copy /b
RM=del

# Builder directories
CONFIG_DIR=config
STYLES_DIR=styles

# External data sources
GEOFABRIK_URL=http://download.geofabrik.de/europe/
OSM_PBF_NAME=hungary-latest.osm.pbf

# Local data caches
DATASET_DIR=c:\Dataset\map
PBF_CACHE_DIR=$(DATASET_DIR)\osm
DEM_DIR=$(DATASET_DIR)\dem
CONTOUR_DIR=$(DATASET_DIR)\contour

CONTOUR_FILE_NAME=contour-hungary.pbf

# PBF Generation
BOUNDARY_POLYGON=$(CONFIG_DIR)\hungary.poly

MERGED_PBF_NAME=hungary-merged.pbf
MERGED_PBF=$(PBF_CACHE_DIR)\$(MERGED_PBF_NAME)

OSMOSIS_INP_OSM_PBF := $(foreach pbf,$(OSM_PBF_NAME),--read-pbf file=$(PBF_CACHE_DIR)\$(pbf))
OSMOSIS_INP_CONT_PBF := $(foreach pbf,$(CONTOUR_FILE_NAME),--read-pbf file=$(CONTOUR_DIR)\$(pbf))
OSMOSIS_INP_PBF=$(OSMOSIS_INP_OSM_PBF) $(OSMOSIS_INP_CONT_PBF)

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
	$(WGET) $(GEOFABRIK_URL)$(OSM_PBF_NAME) -P $(PBF_DIR)

$(MERGED_PBF): $(OSM_PBF)
	$(OSMOSIS) $(OSMOSIS_INP_PBF) --merge --bp file=$(BOUNDARY_POLYGON) --write-pbf file=$(MERGED_PBF) omitmetadata=yes

tiles: $(MERGED_PBF)
	java -Xmx1024m -ea -jar $(SPLITTER) --mapid=71221559  --max-nodes=1600000 --max-areas=255 $(MERGED_PBF) --output-dir=$(TILES_DIR)


$(MERGED_ARGS): $(OHM_ARGS_TEMPLATE) $(TILE_ARGS)
	$(COPY) $(OHM_ARGS_TEMPLATE) + $(TILE_ARGS) $(MERGED_ARGS)

$(MDX_FILE): $(STYLES2) $(MERGED_ARGS)
	java -Xmx4192M -ea -jar $(MKGMAP) $(TYP_FILE) --dem=$(DEM_DIR) --dem-poly=$(BOUNDARY_POLYGON) --style-file=$(STYLES_DIR)\ --output-dir=$(GMAP_DIR) -c $(MERGED_ARGS) --max-jobs=2


map: $(MDX_FILE)
	@echo "Completed"

install:
	$(COPY) $(CONFIG_DIR)\icon.ico $(GMAP_DIR)
	$(COPY) $(TYP_FILE) $(GMAP_DIR)
	$(MKNSIS) $(GMAP_DIR)\openhiking.nsi

clean:
	$(RM) $(GMAP_DIR)\*
