#######################################################
# OpenHikingMap
#
# DEM Tile Manager
#
# Copyright (c) 2021-2022 OpenHiking contributors
# SPDX-License-Identifier: GPL-3.0-only
#
########################################################


from shapely.geometry import MultiPolygon, Polygon, Point
from ftplib import FTP
import math
import os
from os.path import join, exists, basename, isfile
from zipfile import ZipFile
from optparse import OptionParser
import sys

ALOS_FTP_SRV="ftp.eorc.jaxa.jp"
ALOS_ROOT = '/pub/ALOS/ext1/AW3D30/release_v2012_single_format/'

def parse_poly(lines):
    in_ring = False
    coords = []

    for (index, line) in enumerate(lines):
        if index == 0:
            # first line is junk.
            continue

        elif index == 1:
            # second line is the first polygon ring.
            coords.append([[], []])
            ring = coords[-1][0]
            in_ring = True

        elif in_ring and line.strip() == 'END':
            # we are at the end of a ring, perhaps with more to come.
            in_ring = False

        elif in_ring:
            # we are in a ring and picking up new coordinates.
            ring.append(list(map(float, line.split())))

        elif not in_ring and line.strip() == 'END':
            # we are at the end of the whole polygon.
            break

        elif not in_ring and line.startswith('!'):
            # we are at the start of a polygon part hole.
            coords[-1][1].append([])
            ring = coords[-1][1][-1]
            in_ring = True

        elif not in_ring:
            # we are at the start of a polygon part.
            coords.append([[], []])
            ring = coords[-1][0]
            in_ring = True

    return MultiPolygon(coords)

def read_poly(fname):
    with open(fname,'rt') as f:
        polyLines = f.readlines()

    return parse_poly(polyLines)

def get_tile_name(lon, lat, lwidth=2):
    lonTag = "E" if lon >=0 else "W"
    latTag = "N" if lat >=0 else "S"
    return "{:}{:0{width}d}{:}{:03d}".format(latTag, abs(lat), lonTag,abs(lon),width=lwidth)


def get_polygon_tiles(poly):
    minLon, minLat, maxLon, maxLat = poly.bounds
    minLonI = int(math.floor(minLon))
    minLatI = int(math.floor(minLat))
    maxLonI = int(math.ceil(maxLon))
    maxLatI = int(math.ceil(maxLat))

    tileList = []

    for lat in range(minLatI, maxLatI+1):
        for lon in range(minLonI, maxLonI+1):
            tile = Polygon([(lon, lat), (lon+1, lat), (lon+1, lat+1), (lon, lat+1)])
            if poly.intersects(tile):
                tileList.append((lon, lat))

    return tileList

def get_cached_tile(lon, lat, demDir, sources, extensions=['hgt','tif'],lwidth=2, absPath=False ):
    baseName = get_tile_name(lon, lat, lwidth=lwidth)
    for source in sources:
        for ext in extensions:
            rp = join(source,baseName + "." + ext)
            fp = join(demDir, rp) if demDir is not None else rp
            if exists(fp):
                if absPath is True:
                    return fp
                else:
                    return(rp)
    return None



def get_alos_ftp_dir(lon, lat):
    lon2 = lon - lon%5
    lat2 = lat - lat%5
    return ALOS_ROOT+get_tile_name(lon2, lat2, lwidth=3)


def download_alos_tiles(tileList, targetDir):
    ftp = FTP(ALOS_FTP_SRV)
    ftp.login()
    cdir = None
    for lon, lat in tileList:
        tileName = get_tile_name(lon, lat, lwidth=3)
        tileName = tileName + '.zip'
        tdir = get_alos_ftp_dir(lon, lat)
        if tdir != cdir:
            ftp.cwd(tdir)
            cdir = tdir
        print('Downloading %s from %s' % (tileName, tdir))
        with open(join(targetDir, tileName), 'wb') as fp:
            try:
                ftp.retrbinary('RETR '+tileName, fp.write)
            except:
                print("FAILED to download ", tileName)

    ftp.quit()


def extract_alos_zip(zipFullPath, dem_dir, targetName=None):
    with ZipFile(zipFullPath, 'r') as zipObj:
        for fname in zipObj.namelist():
            if fname.endswith("_DSM.tif"):
                if targetName is None:
                    targetName = basename(fname)

                with zipObj.open(fname,'r') as f:
                    data = f.read()

                with open(join(dem_dir, targetName),"wb") as f:
                    f.write(data)


def refresh_alos_tiles(demDir, tileList ):
    missingTiles = []
    downloadList= []

    alosCacheDir = join(demDir, 'alos')

    for tile in tileList:
        lon, lat = tile
        if get_cached_tile(lon, lat, demDir, ['alos'], ['tif']) is not None:
            continue

        missingTiles.append(tile)

    print("Missing tiles: {:} / {:}".format(len(missingTiles), len(tileList)))

    for tile in missingTiles:
        lon, lat = tile
        if get_cached_tile(lon, lat, demDir, ['alos'], ['zip'], lwidth=3) is not None:
            continue

        downloadList.append(tile)

    if len(downloadList)>0:
        download_alos_tiles(downloadList, alosCacheDir)


    for tile in missingTiles:
        lon, lat = tile

        zipFullPath = get_cached_tile(lon, lat, demDir, ['alos'], ['zip'], lwidth=3, absPath=True)

        if zipFullPath is None or exists(zipFullPath) is False:
            print("Missing ", zipFullPath)
            continue

        st = os.stat(zipFullPath)
        if st.st_size < 100:
            print("Invalid ZIP size {:} for {:}".format(st.st_size, zipName))
            continue

        tileName = get_tile_name(lon, lat) + '.tif'
        print("Extract %s from %s" % (tileName, zipFullPath))
        extract_alos_zip(zipFullPath, alosCacheDir, tileName)



def select_dem_sources(demDir, tileList, sourceDirs, ignore):
    sourceNames = []

    for lon, lat in tileList:
        sname = get_cached_tile(lon, lat, demDir, sourceDirs, ['hgt', 'tif'])
        if sname is not None:
            sourceNames.append(sname)
        elif ignore is False:
            print("Missing {:} {:}".format(lat, lon))

    return sourceNames

def select_missing_tiles(demDir, tileList, source, prefix, postfix):
    ext = 'tif' if source=='alos' else 'hgt'
    for lon, lat in tileList:
        sname = get_cached_tile(lon, lat, demDir, [source], [ext])
        if sname is not None:
            continue

        tileName = get_tile_name(lon, lat) + postfix
        print(prefix + tileName)


def display_cache_stats(demDir, tileList, sources):
    n_tiles = len(tileList)
    print("{:>10} {:>5}  {:>5}  {:>5}".format("Source", "Tiles", "#zip", "#hgt"))
    for source in sources:
        n_zip = 0
        n_hgt = 0
        zlwidth = 3 if source=="alos" else 2
        for lon, lat in tileList:
            if get_cached_tile(lon, lat, demDir, [source], ['zip'], lwidth=zlwidth) is not None:
                n_zip += 1
            if get_cached_tile(lon, lat, demDir, [source], ['hgt', 'tif']) is not None:
                n_hgt += 1

        print("{:>10} {:>5}  {:>5}  {:>5}".format(source, n_tiles, n_zip, n_hgt))



def parse_commandline():
    parser = OptionParser(usage="%prog [options] <dem dir> [<dem dir> ...]")
    parser.add_option("-r", "--refresh-alos",
                      dest="alos", action="store_true", default=False,
                      help="Refresh alos files")
    parser.add_option("-s", "--select-sources",
                      dest="select", action="store_true", default=False,
                      help="Select DEM source files")
    parser.add_option("-m", "--missing",
                      dest="missing", action="store_true", default=False,
                      help="List missing DEM tiles")
    parser.add_option("-c", "--cache-stats",
                      dest="stats", action="store_true", default=False,
                      help="Display cache stats")
    parser.add_option("-i", "--ignore",
                      dest="ignore", action="store_true", default=False,
                      help="Ignore missing DEM source files")
    parser.add_option("-p", "--poly",
                      dest="polygon", action="store",
                      help="POLY file name")
    parser.add_option("-d", "--dem",
                      dest="demdir", action="store", default="",
                      help="DEM root directory")


    opts, args = parser.parse_args()

    if opts.alos is False and opts.select is False and opts.missing is False and opts.stats is False:
        print("Missing command")
        sys.exit(1)

    if opts.missing is True and len(args) < 1:
        print("Missing sources")
        sys.exit(1)

    if opts.polygon is None:
        print("Missing polygon")
        sys.exit(1)

    try:
        os.stat(opts.polygon)
    except OSError:
        print("Couldn't find polygon file: {0:s}".format(opts.polygon))
        sys.exit(1)
    if not isfile(opts.polygon):
        print("Polygon file '{0:s}' is not a regular file".format(opts.polygon))
        sys.exit(1)


    if len(args) < 1:
        print("Missing DEM directories")
        sys.exit(1)


    poly = read_poly(opts.polygon)
    opts.tiles = get_polygon_tiles(poly)

    return opts, args

def main():
    opts, args = parse_commandline()

    if opts.alos is True:
        refresh_alos_tiles(opts.demdir, opts.tiles)
        return

    if opts.select is True:
        sourceNames = select_dem_sources(opts.demdir, opts.tiles, args, opts.ignore)

        print(' '.join(sourceNames))

    if opts.missing is True:
        source = args[0]
        prefix = args[1] if len(args) > 1 else ''
        postfix = args[2] if len(args) > 2 else ''
        select_missing_tiles(opts.demdir, opts.tiles, args[0], prefix, postfix)


    if opts.stats is True:
        display_cache_stats(opts.demdir, opts.tiles, args)

if __name__=="__main__":
	main()
