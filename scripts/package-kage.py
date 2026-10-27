#!/usr/bin/env python3
"""Assemble a locally signed macOS-only Kage build. No publishing or key access."""
from pathlib import Path
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
IDENTIFIER = "com.basriakkaya.kage"
PINNED_TOOLS = {
    "ffmpeg": "591260c945d0eef150e3bf82b0ef988bd36a9cecc18ff05d6679617159f0a95e",
    "ffprobe": "e11c17e8200b3ee4c4c186d245e2b4053f01d56957336c1817fca0b997469106",
    "yt-dlp": "0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202",
    # Executable extracted from the project's SHA-256 verified Deno 2.9.7 archive.
    "deno": "b73737579d5a84c160e3316487594783fa5c15f4e13252a6a07050b755317f1a",
}

def run(*args):
    subprocess.run([str(value) for value in args], check=True)

def copy(source, destination):
    run("/usr/bin/ditto", source, destination)

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def sign(path, entitlements=None):
    args = ["/usr/bin/codesign", "--force", "--sign", "-", "--options", "0", "--timestamp=none"]
    if entitlements:
        args.extend(["--entitlements", str(entitlements)])
    run(*args, path)

def main():
    binary = Path(sys.argv[1]).resolve() / "Nashi"
    target = Path(sys.argv[2]).absolute()
    if target.suffix != ".app" or target.is_symlink():
        raise ValueError("Choose a regular .app output path.")
    if target.exists():
        info = target / "Contents/Info.plist"
        if not info.is_file() or plistlib.loads(info.read_bytes()).get("CFBundleIdentifier") != IDENTIFIER:
            raise ValueError("Refusing to replace an unrelated application.")
    for name, expected in PINNED_TOOLS.items():
        if digest(ROOT / "Tools" / name) != expected:
            raise ValueError(name + " does not match the verified Kage tool version.")
    office = ROOT / "Tools/LibreOffice.app"
    if not (office / "Contents/MacOS/soffice").is_file():
        raise ValueError("Prepare the verified LibreOffice app in Tools/LibreOffice.app.")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", office)
    target.parent.mkdir(parents=True, exist_ok=True)
    stage = target.with_name(".Kage-build-" + uuid.uuid4().hex + ".app")
    backup = target.with_name(".Kage-backup-" + uuid.uuid4().hex + ".app")
    try:
        contents = stage / "Contents"
        resources = contents / "Resources"
        tools = resources / "Tools"
        (contents / "MacOS").mkdir(parents=True)
        tools.mkdir(parents=True)
        shutil.copy2(binary, contents / "MacOS/Kage")
        shutil.copy2(ROOT / "Resources/KageInfo.plist", contents / "Info.plist")
        for name in ("Localizations", "Sounds", "licenses"):
            source = ROOT / "Resources" / name
            copy(source, resources if name == "Localizations" else resources / name)
        for name in ("PagesInterop.js", "PDFLib.js", "PDFInterop.js", "KageIcon.icns", "THIRD-PARTY-NOTICES.txt"):
            shutil.copy2(ROOT / "Resources" / name, resources / name)
        shutil.copy2(ROOT / "LICENSE", resources / "licenses/Nashi-MIT.txt")
        shutil.copy2(ROOT / "Resources/KAGE-NOTICE.txt", resources / "licenses/Kage-NOTICE.txt")
        copy(binary.parent / "Nashi_NashiCore.bundle", resources / "Nashi_NashiCore.bundle")
        for name in PINNED_TOOLS:
            shutil.copy2(ROOT / "Tools" / name, tools / name)
        copy(ROOT / "Tools/ExifTool", tools / "ExifTool")
        copy(office, tools / "LibreOffice.app")
        sparkle = ROOT / ".build/artifacts/sparkle/Sparkle"
        framework = contents / "Frameworks/Sparkle.framework"
        framework.parent.mkdir()
        copy(sparkle / "Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework", framework)
        shutil.copy2(sparkle / "LICENSE", resources / "licenses/Sparkle-LICENSE.txt")
        embedded = framework / "Versions/B"
        sign(embedded / "XPCServices/Installer.xpc")
        run("/usr/bin/codesign", "--force", "--sign", "-", "--options", "0", "--timestamp=none", "--preserve-metadata=entitlements", embedded / "XPCServices/Downloader.xpc")
        sign(embedded / "Autoupdate"); sign(embedded / "Updater.app"); sign(framework)
        for name in PINNED_TOOLS:
            sign(tools / name, ROOT / "Configuration/Deno.entitlements" if name == "deno" else None)
        manifest = {"product": "Kage", "signing": "local ad-hoc", "updates": "disabled", "sourceToolSHA256": PINNED_TOOLS,
                    "sourceRevision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                    "sourceDirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())}
        (resources / "Kage-build.json").write_text(json.dumps(manifest, indent=2) + "\n")
        sign(stage)
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", stage)
        if target.exists():
            os.replace(target, backup)
        try:
            os.replace(stage, target)
        except BaseException:
            if backup.exists(): os.replace(backup, target)
            raise
        if backup.exists(): shutil.rmtree(backup)
        print(target)
    finally:
        if stage.exists(): shutil.rmtree(stage)

if __name__ == "__main__":
    main()
