#######################################################
# OpenHikingMap
#
# TYP File Checker
#
# Copyright (c) 2021-2022 OpenHiking contributors
# SPDX-License-Identifier: GPL-3.0-only
#
########################################################


from os.path import join
from optparse import OptionParser
import re
import sys

class TypChecker(object):
    sectionHeaders = {
        '[_id]' : 'I',
        '[_comments]': 'C',
        '[_drawOrder]': 'O',
        '[_polygon]': 'P',
        '[_line]': 'L',
        '[_point]':'T'
    }
    idKeys=['ProductCode', 'FID', 'CodePage']
    commonKeys=['String1','String2','String3','String4','ExtendedLabels','FontStyle','CustomColor','ContourColor','UseOrientation']
    lineKeys=['LineWidth','BorderWidth']
    pointKeys=['CustomColor','DaycustomColor','NightcustomColor','ContourColor']

    def __init__(self):
        self.reDrawOrder = re.compile('^Type=0x[0-9a-fA-F]{1,5},\d$')
        self.reType = re.compile('^Type=0x([0-9a-fA-F]{1,5})$')
        self.reXpm = re.compile("\"(?P<cols>\d+) (?P<rows>\d+) (?P<colors>\d+)\s+(?P<symlen>\d+)\"")
        self.reDayXpm = re.compile("\"(?P<cols>\d+)\s(?P<rows>\d+)\s(?P<colors>\d+)\s+(?P<symlen>\d+)\" +Colormode=\d+")
        self.reColorDef = re.compile("\"[^ ]{1,3}\s+c\s+(#[0-9a-fA-F]{6}|none)\"")
        self.reColorDef2 = re.compile("\"\s+c\s+none\"")

        self.polyTypes = {}
        self.lineTypes = {}
        self.pointTypes = {}

    def _enter_section(self, code):
        #print("ENTER", code)
        self.section = code
        self.sectionpos = 0
        return True

    def _exit_section(self):
        #print("EXIT", self.section)
        self.section = 'M'
        return True

    def _check_main(self, n, line):
        code= self.sectionHeaders.get(line)
        if code is not None:
            return self._enter_section(code)

        print("{:} Unexpected section".format(n), line)
        return False


    def _check_id(self, n, line):
        for kw in self.idKeys:
            if line.startswith(kw):
                return True

        if line=='[End]':
            return self._exit_section()

        print("{:} Unexpected Id keyword".format(n), line)
        return False

    def _check_comments(self, n, line):
        if line=='[End]':
            return self._exit_section()

        return True

    def _check_draworder(self, n, line):
        mo = self.reDrawOrder.match(line)
        if mo is not None:
            return True

        if line=='[End]':
            return self._exit_section()

        print("{:} Unexpected draworder".format(n), line)
        return False, None

    def _check_type(self, n, line):
        hits = self.reType.findall(line)
        if len(hits) == 0:
            print("{:} Type code is expected".format(n), line)
            return False

        tc = hits[0]
        if self.section=='P':
            if self.polyTypes.get(tc) is not None:
                print("{:} Type code is not unique".format(n), line)
            else:
                self.polyTypes[tc] = 1
        elif self.section=='L':
            if self.lineTypes.get(tc) is not None:
                print("{:} Type code is not unique".format(n), line)
            else:
                self.lineTypes[tc] = 1
        elif self.section=='T':
            if self.pointTypes.get(tc) is not None:
                print("{:} Type code is not unique".format(n), line)
            else:
                self.pointTypes[tc] = 1

        self.sectionpos=1
        return True

    def _check_section_attributes(self, n, line):
        parts = line.split('=',maxsplit=1)
        if len(parts) != 2:
            parts = line.split(':', maxsplit=1)
            if len(parts) != 2:
                print("{:} Attribute format mismatch".format(n), line)
                return False

        key = parts[0]
        val = parts[1]
        if key in self.commonKeys:
            return True

        if self.section=='L' and key in self.lineKeys:
            return True

        if self.section=='T' and key in self.pointKeys:
            return True

        #print("<>",key,":", val)
        mo = None
        if key == 'Xpm':
            mo = self.reXpm.match(val)
            if mo is None:
                print("{:} Unexpected Xpm format".format(n), line)
                return False

        if key == 'DayXpm':
            mo = self.reDayXpm.match(val)
            if mo is None:
                print("{:} Unexpected DayXpm format".format(n), line)
                return False

        if mo is not None:
            gd = mo.groupdict()
            self.xcols = int(gd['cols'])
            self.xrows =int(gd['rows'])
            self.xcolors = int(gd['colors'])
            self.xsymlen = int(gd['symlen'])
            self.xbitdefw = self.xcols * self.xsymlen + 2
            self.sectionpos = 2
            return True


        print("{:} Unexpected attribute".format(n), line)
        return False

    def _check_color_def(self, n, line):
        mo = self.reColorDef.match(line)
        if mo is None:
            mo = self.reColorDef2.match(line)

            if mo is None:
                print("{:} Unrecognized color def".format(n), line)
                return False

        self.xcolors -= 1
        if self.xcolors == 0:
            if self.xrows > 0:
                self.sectionpos = 3
            else:
                self.sectionpos = 1
        return True

    def _check_bitmap(self, n, line):
        if len(line) != self.xbitdefw:
            print("{:} Bitmap def col mismatch".format(n), line)
            return False
        if line[0] != '"' or line[-1]!= '"':
            print("{:} Bitmap def \" missing".format(n), line)
            return False

        self.xrows -= 1
        if self.xrows == 0:
            self.sectionpos = 1
        return True

    def _check_bitmap_term(self, n, line):
        if len(line) != self.xcols + 2 or line[0] != ';':
            print("{:} Bitmap termination error".format(n), line)
            return False
        self.sectionpos = 1
        return True


    def _check_element(self, n, line):
        if self.sectionpos == 0:
            return self._check_type(n, line)

        if self.sectionpos == 1:
            if line=='[End]' or line=='[end]':
                return self._exit_section()

            return self._check_section_attributes(n, line)

        if self.sectionpos == 2:
            return self._check_color_def(n, line)

        if self.sectionpos == 3:
            return self._check_bitmap(n, line)

        if self.sectionpos == 4:
            return self._check_bitmap_term(n, line)

        print("Unhandled pos")
        return False


    def check(self, typFile):

        with open( typFile,"rt", encoding='utf-8') as f:
            lines = f.readlines()

        self.section='M'
        for n, line in enumerate(lines):
            line = line.strip()
            ##print(line)
            if len(line) == 0 or line[0] == ';':
                continue

            if self.section=='M':
                res = self._check_main(n, line)
            elif self.section=='I':
                res = self._check_id(n, line)
            elif self.section=='C':
                res = self._check_comments(n, line)
            elif self.section=='O':
                res = self._check_draworder(n, line)
            elif self.section=='P':
                res = self._check_element(n, line)
            elif self.section=='L':
                res = self._check_element(n, line)
            elif self.section=='T':
                res = self._check_element(n, line)
            else:
                print('Unknown section')
                res = False

            if res is False:
                return False

        return True

def parse_commandline():
    parser = OptionParser(usage="%prog  <typfile> ")
    opts, args = parser.parse_args()

    if len(args) < 1:
        print("Missing TYP file")
        sys.exit(1)

    return opts, args

def main():
    opts, args = parse_commandline()

    chk = TypChecker()
    chk.check(args[0])

if __name__=="__main__":
	main()
