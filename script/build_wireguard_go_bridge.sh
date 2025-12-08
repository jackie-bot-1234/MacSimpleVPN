#!/bin/sh

# --- Variable Calculation (Keep your existing logic here) ---
project_data_dir="$BUILD_DIR"

while true; do
    parent_dir=$(dirname "$project_data_dir")
    basename=$(basename "$project_data_dir")
    project_data_dir="$parent_dir"
    if [ "$basename" = "Build" ]; then
        break
    fi
done

checkouts_dir="$project_data_dir"/SourcePackages/checkouts
if [ -e "$checkouts_dir"/wireguard-apple ]; then
    checkouts_dir="$checkouts_dir"/wireguard-apple
fi

wireguard_go_dir="$checkouts_dir"/Sources/WireGuardKitGo

# --- Build Environment Setup (UPDATED) ---

export PATH="${PATH}:/opt/homebrew/bin:/usr/local/bin"
export CGO_ENABLED=1

cd "$wireguard_go_dir" || exit 1

echo "Building in: $wireguard_go_dir"

# 1. Get macOS SDK Path (Crucial for CGO)
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
if [ -z "$SDK_PATH" ]; then
    echo "Error: Could not find macOS SDK"
    exit 1
fi

# 2. Build for arm64 (Apple Silicon)
echo "Building for arm64..."
export GOOS=darwin
export GOARCH=arm64
export CGO_CFLAGS="-arch arm64 -isysroot $SDK_PATH"
export CGO_LDFLAGS="-arch arm64 -isysroot $SDK_PATH"

# direct go build command bypasses the Makefile
go build -tags macos -ldflags=-w -trimpath -v -o "libwireguard_arm64.a" -buildmode=c-archive

if [ ! -f "libwireguard_arm64.a" ]; then
    echo "Error: Failed to build libwireguard_arm64.a"
    exit 1
fi

# 3. Build for x86_64 (Intel Macs)
echo "Building for x86_64..."
export GOOS=darwin
export GOARCH=amd64
export CGO_CFLAGS="-arch x86_64 -isysroot $SDK_PATH"
export CGO_LDFLAGS="-arch x86_64 -isysroot $SDK_PATH"

go build -tags macos -ldflags=-w -trimpath -v -o "libwireguard_x86_64.a" -buildmode=c-archive

if [ ! -f "libwireguard_x86_64.a" ]; then
    echo "Error: Failed to build libwireguard_x86_64.a"
    exit 1
fi

# 4. Create the Universal (FAT) Binary
echo "Combining into universal binary..."
/usr/bin/lipo -create libwireguard_arm64.a libwireguard_x86_64.a -output libwg-go.a

# 5. Clean up intermediates
rm libwireguard_arm64.a libwireguard_x86_64.a

echo "Copying libwg-go.a to ${CONFIGURATION_BUILD_DIR}"
cp -f libwg-go.a "${CONFIGURATION_BUILD_DIR}/libwg-go.a"

echo "Universal library libwg-go.a created successfully."
