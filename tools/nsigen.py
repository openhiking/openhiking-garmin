#######################################################
# OpenHikingMap
#
# NSI Script generator
#
# Copyright (c) 2021-2022 OpenHiking contributors
# SPDX-License-Identifier: GPL-3.0-only
#
########################################################

from os import listdir
from os.path import isfile, join
from optparse import OptionParser
import sys

def write_defines(outputFile, varlist):
    for varName, value in varlist.items():
        if value is not None:
            nl = "!define {:} \"{:}\"\n".format(varName, value)
        else:
            nl = "!define {:}\n".format(varName)

        outputFile.write(nl)

def write_icon(outputFile, iconName):
    if iconName is not None:
        nl = "!define MUI_ICON \"%s\"" % (iconName)
        outputFile.write(nl)

def write_images(outputFile, imageList):
    for imageName in imageList:
        nl = "  File \"%s\"\n" % (imageName)
        outputFile.write(nl)

def write_delete_images(outputFile,  imageList):
    for imageName in imageList:
        nl =  "  Delete \"$INSTDIR\%s\"\n" % imageName
        outputFile.write(nl)

def write_regbin(outputFile, family_id):
    hval = '000' + hex(family_id)[2:]
    hval = hval[-2:] + hval[-4:-2]
    nl = "  WriteRegBin HKLM \"SOFTWARE\Garmin\MapSource\Families\${REG_KEY}\" \"ID\" %s\n" % hval
    outputFile.write(nl)

def process_template(inputFile, outputFile, family_id, varlist, iconName, imageList):
    with open(inputFile, "rt") as inf:
        with open(outputFile,"wt") as outf:
            for line in inf:
                if line[0] == ';':
                    if line.find('INSERT_DEFINES_HERE') > 0:
                        write_defines(outf, varlist)
                        continue
                    if line.find('INSERT_ICON_HERE') > 0:
                        write_icon(outf, iconName)
                        continue
                    if line.find('INSERT_ADDED_FILES_HERE') > 0:
                        write_images(outf, imageList)
                        continue
                    if line.find('INSERT_REMOVED_FILES_HERE') > 0:
                        write_delete_images(outf,  imageList)
                        continue
                    if line.find('INSERT_REGBIN_HERE') > 0:
                        write_regbin(outf,  family_id)
                        continue
                outf.write(line)

def find_images(gmap_dir, mapName):
    imgList= [f for f in listdir(gmap_dir) if isfile(join(gmap_dir, f)) and f.endswith('.img')]

    defaultImages=["%s.img" % mapName, "%s_mdr.img" % mapName, 'gmapsupp.img']
    myList = [f for f in imgList if f not in defaultImages]
    return myList


def parse_commandline():
    parser = OptionParser(usage="%prog [options] <nsi template> <gmap dir>")
    parser.add_option("-f", "--family-name",
                      dest="family_name", action="store",
                      help="Set FAMILY_NAME")
    parser.add_option("-g", "--family-id",
                      dest="family_id", action="store",
                      help="Set FAMILY_NAME")
    parser.add_option("-m", "--mapname",
                      dest="mapname", action="store",
                      help="Set MAPNAME")
    parser.add_option("-p", "--product-id",
                      dest="product", action="store",
                      help="Set product ID")
    parser.add_option("-t", "--typ-name",
                      dest="typname", action="store",
                      help="Set TYP name")
    parser.add_option("-i", "--icon-name",
                      dest="icon", action="store",
                      help="Set icon name")
    parser.add_option("-x", "--installer-name",
                      dest="installer", action="store",
                      help="Set installer name")

    opts, args = parser.parse_args()

    if opts.family_name is None:
        print("Missing family name")
        sys.exit(1)

    if opts.family_id is None:
        print("Missing family ID")
        sys.exit(1)

    if opts.mapname is None:
        print("Missing mapname")
        sys.exit(1)

    if opts.product is None:
        print("Missing product Id")
        sys.exit(1)

    if opts.typname is None:
        print("Missing TYP name")
        sys.exit(1)


    if len(args) < 2:
        print("Missing gmap directory")
        sys.exit(1)


    return opts, args


def main():
    opts, args = parse_commandline()

    nsiTemplate = args[0]
    gmapDir = args[1]
    installer = opts.installer if opts.installer is not None else opts.family_name

    varList = {
        'DEFAULT_DIR' : "C:\Garmin\Maps\%s" % opts.family_name,
        'INSTALLER_DESCRIPTION': opts.family_name,
        'INSTALLER_NAME': installer,
        'MAPNAME':  opts.mapname,
        'PRODUCT_ID':  opts.product,
        'REG_KEY':  opts.family_name,
        'INDEX': None,
        'TYPNAME':  opts.typname
    }

    imageList = find_images(gmapDir, opts.mapname)

    outputFile = join(gmapDir, opts.mapname + ".nsi")

    pl = "Writing {:} with {:} img files, typ={:} icon={:}".format(outputFile, len(imageList), opts.typname, opts.icon)
    print(pl)
    process_template(nsiTemplate, outputFile, int(opts.family_id), varList, opts.icon, imageList)
    print("Done")




if __name__=="__main__":
	main()
