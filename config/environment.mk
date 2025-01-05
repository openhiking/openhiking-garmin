#######################################################
# OpenHikingMap
#
# Map making automation
# Copyright (c) 2021-2024 OpenHiking contributors
# SPDX-License-Identifier: GPL-3.0-only
#
########################################################

OSM_CACHE_DIR=${MKG_OSM_CACHE_DIR}
ifeq ($(OSM_CACHE_DIR),)
$(error MKG_OSM_CACHE_DIR env variable must be set)
endif

DEM_DIR=${MKG_DEM_DIR}
ifeq ($(DEM_DIR),)
$(error MKG_DEM_DIR env variable must be set)
endif

ALOS_DOWNLOAD_SUBDIR=${MGK_ALOS_DOWNLOAD_SUBDIR}

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
MAPSOURCE_DIR?=${MKG_MAPSOURCE_DIR}

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

ifneq (${MKG_ROUTEMAPPER},)
ROUTEMAPPER=${MKG_ROUTEMAPPER}
endif

ifneq (${MKG_MAKENAMES},)
MAKENAMES=${MKG_MAKENAMES}
endif

ifneq (${MKG_DEMMGR},)
DEMMGR=${MKG_DEMMGR}
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

ifneq (${MKG_SPLITTER_MAX_NODES},)
SPLITTER_MAX_NODES=${MKG_SPLITTER_MAX_NODES}
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

ifneq (${MKG_MKGMAP_MEMORY},)
MKGMAP_MEMORY=${MKG_MKGMAP_MEMORY}
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
	ZIPARGS?=-r
	PSEP=$(subst /,/,/)
	PSEP2=$(PSEP)
	CMDLIST=&&
	COPY=cp
	MOVE=mv
	DEL=rm -rf
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
	ZIPARGS?=a -tzip
	PSEP=$(subst /,\,/)
	PSEP2=$(PSEP)$(PSEP)
	CMDLIST=&
	COPY=copy /b
	MOVE=move
	DEL=del /f /q
        RMDIR=rmdir /s /q
endif

#DEMMGR=tools$(PSEP)demmgr.py
PHYGHTMAP?=phyghtmap
WGET?=wget
NSIGEN?=python tools\nsigen.py
