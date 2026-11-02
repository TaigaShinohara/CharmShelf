#!/usr/bin/env python3
"""Copy the checked-in Isar library beside host tests; never download binaries."""
from pathlib import Path
import platform, shutil
ROOT = Path(__file__).resolve().parents[2]
def main():
    system = platform.system()
    paths = {"Darwin": ("macos/libisar.dylib", "libisar.dylib"), "Linux": ("linux/libisar.so", "libisar.so"), "Windows": ("windows/isar.dll", "isar.dll")}
    if system not in paths:
        raise SystemExit("Unsupported host; supported hosts: macOS, Linux, Windows")
    source, name = paths[system]
    source = ROOT / "patches/isar_flutter_libs" / source
    if not source.is_file() or source.is_symlink():
        raise SystemExit("Missing checked-in host Isar library")
    destination = ROOT / name
    if destination.is_symlink():
        raise SystemExit("Refusing to replace a symlink")
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    shutil.copyfile(source, temporary)
    temporary.replace(destination)
    print("Prepared checked-in Isar host library:", name)
if __name__ == "__main__":
    main()
