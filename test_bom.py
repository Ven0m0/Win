import sys

def check_bom(filename):
    with open(filename, "rb") as f:
        bytes = f.read(3)
        if bytes == b'\xef\xbb\xbf':
            print(f"{filename} HAS UTF-8 BOM")
        else:
            print(f"{filename} DOES NOT HAVE UTF-8 BOM")

check_bom("Scripts/steam.ps1")
check_bom("Scripts/steam.Tests.ps1")
