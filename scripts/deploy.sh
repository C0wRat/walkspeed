#!/bin/sh
# Builds WalkSpeed, installs it on an iPhone and launches it.
#
# Usage: scripts/deploy.sh [device]
#
# `device` is the iPhone's name or UDID. Without it, the first paired iPhone
# is used. The iPhone has to be connected by USB, or on the same Wi-Fi
# network as this Mac after a first install over USB.

set -eu
cd "$(dirname "$0")/.."

# Use Xcode even when xcode-select points at the Command Line Tools.
if ! xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

bundle_id=com.c0wrat.walkspeed
configuration=Release
derived_data=build/DerivedData
devices_json=$(mktemp)
trap 'rm -f "$devices_json"' EXIT

xcrun devicectl list devices --quiet --json-output "$devices_json" >/dev/null

# Prints "<udid> <name>" for the requested iPhone, or for the first paired one.
device=$(/usr/bin/python3 -I - "$devices_json" "${1:-}" <<'PY'
import json
import sys

devices = json.load(open(sys.argv[1]))["result"]["devices"]
wanted = sys.argv[2]
for device in devices:
    hardware = device.get("hardwareProperties", {})
    name = device.get("deviceProperties", {}).get("name", "")
    paired = device.get("connectionProperties", {}).get("pairingState") == "paired"
    if hardware.get("deviceType") != "iPhone" or not paired:
        continue
    if not wanted or wanted in (name, hardware.get("udid")):
        print(hardware["udid"], name)
        break
PY
)

if [ -z "$device" ]; then
    echo "deploy: no paired iPhone${1:+ named \"$1\"} found. Connect it with a cable, unlock it and try again." >&2
    exit 1
fi
udid=${device%% *}
name=${device#* }

echo "Building WalkSpeed for ${name}..."
xcodebuild \
    -project WalkSpeed.xcodeproj \
    -scheme WalkSpeed \
    -configuration "$configuration" \
    -destination "id=$udid" \
    -derivedDataPath "$derived_data" \
    -allowProvisioningUpdates \
    -quiet \
    build

echo "Installing..."
xcrun devicectl device install app --device "$udid" \
    "$derived_data/Build/Products/$configuration-iphoneos/WalkSpeed.app"

echo "Launching..."
xcrun devicectl device process launch --device "$udid" "$bundle_id"
