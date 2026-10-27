# Kage for macOS

[English](README.md) · [Türkçe](README.tr.md)

A personal file workspace with a black/red interface, terminal-inspired identity and local security inspection. Built independently on the open-source Nashi engine.

![Kage workspace](docs/assets/kage/workspace-dark-tr.png)

## What works

- Native macOS workspace, Library, drag-and-wheel tools and file previews.
- 45 input formats and 27 original file tools: image/PDF/media/document conversion, cropping, annotations, metadata controls, redaction, archive extraction and more.
- **Security Center:** streaming SHA-256, checksum comparison, file-header/extension mismatch observations, executable content/permissions, hidden filename characters, quarantine observations and JSON reports without full paths.
- Security inspection reads files without uploading or executing them. It refuses symlinks, devices and folders, supports cancellation and rejects results if the file changes during inspection. It is not an antivirus or a guarantee that a file is safe.
- Independent bundle identity (`com.basriakkaya.kage`), settings and imports. Original update channels and saved update connections are disabled in Kage builds.
- Turkish/English, light/dark; Turkish and dark are the initial preferences.

Kage incorporates the separately submitted Nashi redaction and archive-boundary fixes. This fork targets **Apple Silicon / macOS 13+**. Windows sources remain upstream reference material and are not a Kage product.

## Build a usable app

Xcode with Swift 6 and Python 3.11+ are required. Runtimes are prepared inside the checkout, not installed system-wide.

```sh
python3 scripts/setup-kage-tools.py
zsh scripts/build-kage.sh release
open build/Kage.app
```

The build bundles the verified media/Office tools, ExifTool, local document libraries and their licenses. Default output: `build/Kage.app`. Override with `KAGE_APP_OUTPUT`.

This is a **locally signed, ad-hoc build**. It is not an Apple-notarized public release. Automatic updates are intentionally disabled until a Kage-owned, signed release channel exists. The app does not disable operating-system protections. Login launch may be unavailable for this local build; moving other applications' windows requires a separate macOS permission and is off by default.

## Use

Choose or drop files, then pick a conversion or tool. **⌘1** opens the workspace, **⌘2** the Library, **⌘3** Security Center. **⌘O** chooses files. Security Center has its own file picker and accepts up to 32 regular files per inspection.

Compare a fingerprint against a value obtained from a trusted source. Matching hashes establish equality with that supplied value; they do not establish publisher identity or malware safety. Metadata/redaction actions produce copies and retain originals.

CLI inspection is also available:

```sh
build/Kage.app/Contents/MacOS/Kage security /path/to/file
```

## Verify

```sh
swift test
python3 scripts/test-native-ui.py --app build/Kage.app/Contents/MacOS/Kage --output work/native-ui
build/Kage.app/Contents/MacOS/Kage --kage-smoke work/packaged-smoke
```

Use new, empty output directories for explicit UI/runtime audits. They use synthetic files. The native audit covers 48 scene/theme/language combinations; the packaged smoke runs real conversions using bundled tools. Those checks do not establish another macOS version or architecture's acceptance.

## Origin and licenses

Kage is an independent customization by Basri Akkaya, based on [Nashi](https://github.com/orkunisitmak/nashi-app) by Orkun Işıtmak and contributors. The original [MIT license](LICENSE), copyright, attribution and third-party licenses are preserved. See [Kage notice](Resources/KAGE-NOTICE.txt), [third-party notices](Resources/THIRD-PARTY-NOTICES.txt) and `Resources/licenses/`. Kage is not an official Nashi release or associated with Tangerine/LEAP STUDIO.
