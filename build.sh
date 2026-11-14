#!/bin/bash
set -euo pipefail

cd -- "$(dirname -- "$0")"
project_root="$PWD"
build_dir="$project_root/build"
mkdir -p "$build_dir"
scratch_dir="$(mktemp -d "$build_dir/.sideglance.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

app="$scratch_dir/Sideglance.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
module_cache="$build_dir/ModuleCache"

xcrun swift -module-cache-path "$module_cache" Scripts/MakeIcon.swift "$app/Contents/Resources/AppIcon.icns"

for architecture in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -target "$architecture-apple-macosx14.0" \
        -module-cache-path "$module_cache" Sources/*.swift -o "$scratch_dir/Sideglance-$architecture"
done
xcrun lipo -create "$scratch_dir/Sideglance-arm64" "$scratch_dir/Sideglance-x86_64" \
    -output "$app/Contents/MacOS/Sideglance"

/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --strict "$app"

destination="$build_dir/Sideglance.app"
rm -rf "$destination"
mv "$app" "$destination"
printf '%s\n' "$destination"
