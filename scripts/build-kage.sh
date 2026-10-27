#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration=${1:-release}
application=${KAGE_APP_OUTPUT:-"$PWD/build/Kage.app"}
python3 scripts/generate-localizations.py
swift build -c "$configuration" --product Nashi -Xswiftc -file-prefix-map -Xswiftc "$PWD=/kage" -Xswiftc -file-compilation-dir -Xswiftc /kage
binary_dir=$(swift build -c "$configuration" --show-bin-path)
python3 scripts/package-kage.py "$binary_dir" "$application"
