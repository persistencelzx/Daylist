#!/usr/bin/env python3
"""Prepare a local-device copy using PNG icons when no simulator runtime exists."""
from pathlib import Path
import hashlib
import plistlib
import shutil
import subprocess
import sys

source = Path(__file__).resolve().parent.parent
target = Path(sys.argv[1]).resolve()
if target == source or source.is_relative_to(target):
    raise SystemExit("The destination must be a separate build directory.")
shutil.copytree(source, target, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(".build", ".swiftpm", "xcuserdata"))
project = target / "Daylist.xcodeproj/project.pbxproj"
text = project.read_text()
build_ids = []
for name, size in [("AppIcon60x60@2x.png", 120), ("AppIcon60x60@3x.png", 180),
                   ("AppIcon76x76@2x.png", 152), ("AppIcon83.5x83.5@2x.png", 167)]:
    subprocess.run(["sips", "-z", str(size), str(size),
                    str(source / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"),
                    "--out", str(target / "App" / name)], check=True, stdout=subprocess.DEVNULL)
    ref = hashlib.sha1(("ref" + name).encode()).hexdigest()[:24].upper()
    build = hashlib.sha1(("build" + name).encode()).hexdigest()[:24].upper()
    build_ids.append(build)
    text = text.replace("/* End PBXBuildFile section */",
        f"{build} = {{isa = PBXBuildFile; fileRef = {ref}; }};\n/* End PBXBuildFile section */")
    text = text.replace("/* End PBXFileReference section */",
        f'{ref} = {{isa = PBXFileReference; lastKnownFileType = image.png; path = "App/{name}"; sourceTree = "<group>"; }};\n/* End PBXFileReference section */')
    text = text.replace("B16B6325BA8F1CFBCC279108 /* App/Assets.xcassets */,",
        f"{ref},\nB16B6325BA8F1CFBCC279108 /* App/Assets.xcassets */,")
text = text.replace("C71C93FFDE9FB06CA3A6635A /* App/Assets.xcassets in Resources */,",
                    "\n".join(f"{identifier}," for identifier in build_ids))
text = text.replace("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;", "")
project.write_text(text)
info = target / "Config/App-Info.plist"
data = plistlib.loads(info.read_bytes())
data["CFBundleIcons"] = {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon60x60"]}}
data["CFBundleIcons~ipad"] = {"CFBundlePrimaryIcon": {
    "CFBundleIconFiles": ["AppIcon60x60", "AppIcon76x76", "AppIcon83.5x83.5"]}}
info.write_bytes(plistlib.dumps(data))
print(target)
