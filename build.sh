#!/bin/bash

# Exit immediately if any command fails
set -e

echo "=== Starting LightConda Native macOS Build ==="

# 1. Setup raw icon asset
RAW_ICON_SRC="AppIcon.png"
if [ -f "$RAW_ICON_SRC" ]; then
    echo "Copying glowing green Conda app icon asset..."
    cp "$RAW_ICON_SRC" app_icon_raw.png
else
    echo "Warning: AppIcon.png not found, using generic rendering..."
fi

# 2. Slice and process app icon using macOS sips tool
if [ -f "app_icon_raw.png" ]; then
    echo "Processing icon asset into standard macOS dimensions using sips..."
    mkdir -p AppIcon.iconset
    sips -z 16 16     app_icon_raw.png --out AppIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     app_icon_raw.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     app_icon_raw.png --out AppIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     app_icon_raw.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   app_icon_raw.png --out AppIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   app_icon_raw.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   app_icon_raw.png --out AppIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   app_icon_raw.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   app_icon_raw.png --out AppIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 app_icon_raw.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
    
    echo "Compiling icns file using macOS iconutil..."
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
fi

# 3. Clean up any previous builds
echo "Cleaning up previous builds..."
rm -rf LightConda.app LightConda.zip build
mkdir -p LightConda.app/Contents/MacOS
mkdir -p LightConda.app/Contents/Resources

# 4. Copy app icon to Resources
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns LightConda.app/Contents/Resources/AppIcon.icns
fi

# 5. Compile Swift sources with SwiftUI support
echo "Compiling Swift source code files..."
swiftc \
    -sdk $(xcrun --show-sdk-path) \
    -target arm64-apple-macos14.0 \
    -O \
    -parse-as-library \
    Sources/App.swift \
    Sources/AppView.swift \
    Sources/CondaManager.swift \
    Sources/CreateEnvSheet.swift \
    Sources/EnvironmentsListView.swift \
    Sources/Models.swift \
    Sources/PackageDetailsSheet.swift \
    Sources/SettingsView.swift \
    -o LightConda.app/Contents/MacOS/LightConda

# 6. Create Info.plist file
echo "Assembling Info.plist properties..."
cat <<EOF > LightConda.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LightConda</string>
    <key>CFBundleIdentifier</key>
    <string>com.mursalatul.LightConda</string>
    <key>CFBundleName</key>
    <string>LightConda</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 7. Clean up temporary files
echo "Cleaning up build artifacts..."
rm -rf AppIcon.iconset AppIcon.icns app_icon_raw.png

# 8. Create distributable zip archive
echo "Packaging LightConda.app into LightConda.zip..."
zip -q -r LightConda.zip LightConda.app

echo "=== Build Succeeded! ==="
echo "You can find your double-clickable app at:"
echo "  - LightConda.app"
echo "And your distributable zip at:"
echo "  - LightConda.zip"
