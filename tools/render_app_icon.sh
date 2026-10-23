#!/bin/sh
# Renders FreeMateIOS/Assets.xcassets/AppIcon.appiconset from tools/render_app_icon.swift.
set -e
cd "$(dirname "$0")/.."
work=$(mktemp -d)
cat FreeMateIOS/DesignSystem/ChessPieceShape.swift tools/render_app_icon.swift > "$work/main.swift"
swiftc -parse-as-library -o "$work/render" "$work/main.swift" 2>/dev/null || swiftc -o "$work/render" "$work/main.swift"
"$work/render" FreeMateIOS/Assets.xcassets/AppIcon.appiconset
rm -rf "$work"
