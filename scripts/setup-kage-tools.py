#!/usr/bin/env python3
"""Prepare pinned runtimes inside this checkout; never installs system-wide."""
from pathlib import Path
import hashlib
import os
import platform
import runpy
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "Tools"
DOWNLOADS = ROOT / "Downloads"
PINNED = runpy.run_path(str(ROOT / "scripts/package-kage.py"))["PINNED_TOOLS"]
OFFICE_SHA256 = "ca074e0b13571efb30a31fc531c5f95e997030637325e5d5de92d67aefdf0dfc"
OFFICE_URL = "https://download.documentfoundation.org/libreoffice/stable/26.8.1/mac/aarch64/LibreOffice_26.8.1_MacOS_aarch64.dmg"

def digest(path):
    with path.open("rb") as stream: return hashlib.file_digest(stream, "sha256").hexdigest()

def fetch(url, destination, maximum):
    temporary = destination.with_suffix(destination.suffix + ".partial")
    try:
        with urllib.request.urlopen(url, timeout=60) as response, temporary.open("wb") as output:
            if not response.url.startswith("https://"): raise ValueError("Insecure tool download redirect")
            total = 0
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > maximum: raise ValueError("Tool download exceeds its limit")
                output.write(chunk)
        os.replace(temporary, destination)
    finally:
        if temporary.exists(): temporary.unlink()

def main():
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise SystemExit("This Kage build targets Apple Silicon macOS.")
    TOOLS.mkdir(exist_ok=True); DOWNLOADS.mkdir(exist_ok=True)
    for name in ("ffmpeg", "ffprobe"):
        target = TOOLS / name
        if target.is_file() and digest(target) == PINNED[name]: continue
        archive = DOWNLOADS / (name + "9arm.zip")
        fetch("https://www.osxexperts.net/" + name + "9arm.zip", archive, 200 * 1024 * 1024)
        with zipfile.ZipFile(archive) as package:
            if package.getinfo(name).file_size > 200 * 1024 * 1024: raise ValueError("Tool executable exceeds its limit")
            data = package.read(name)
        if hashlib.sha256(data).hexdigest() != PINNED[name]: raise ValueError(name + " checksum mismatch")
        temporary = target.with_suffix(".partial"); temporary.write_bytes(data); temporary.chmod(0o755); os.replace(temporary, target)
    if not all((TOOLS / name).is_file() and digest(TOOLS / name) == PINNED[name] for name in ("deno", "yt-dlp")):
        subprocess.run(["python3", str(ROOT / "scripts/setup-web-download-tools.py")], check=True)
    if not (TOOLS / "ExifTool/exiftool").is_file():
        subprocess.run(["zsh", str(ROOT / "scripts/setup-exiftool.sh")], check=True)
    office = TOOLS / "LibreOffice.app"
    if not office.exists():
        image = DOWNLOADS / "LibreOffice_26.8.1_MacOS_aarch64.dmg"
        if not image.is_file() or digest(image) != OFFICE_SHA256: fetch(OFFICE_URL, image, 400 * 1024 * 1024)
        if digest(image) != OFFICE_SHA256: raise ValueError("LibreOffice checksum mismatch")
        with tempfile.TemporaryDirectory(prefix="kage-office-", dir=TOOLS) as temporary:
            stage = Path(temporary); mount = stage / "mount"; mount.mkdir()
            subprocess.run(["hdiutil", "attach", "-nobrowse", "-readonly", "-mountpoint", str(mount), str(image)], check=True)
            try:
                subprocess.run(["ditto", str(mount / "LibreOffice.app"), str(stage / "LibreOffice.app")], check=True)
            finally:
                subprocess.run(["hdiutil", "detach", str(mount)], check=True)
            os.replace(stage / "LibreOffice.app", office)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(office)], check=True)
    if not all(digest(TOOLS / name) == value for name, value in PINNED.items()): raise ValueError("Runtime verification failed")
    print("Kage runtimes ready; verified locally. No system installation.")

if __name__ == "__main__": main()
