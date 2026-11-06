#!/usr/bin/env bash
set -e

echo "=== Configuring Godot Editor Settings for Android CI ==="

SDK_PATH="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
KEYSTORE_PATH="${GITHUB_WORKSPACE:-$(pwd)}/debug.keystore"

mkdir -p ~/.config/godot
mkdir -p ~/.android

if [ -f "$KEYSTORE_PATH" ]; then
    cp "$KEYSTORE_PATH" ~/.android/debug.keystore
fi

cat <<EOF > ~/.config/godot/editor_settings-4.tres
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${SDK_PATH}"
export/android/debug_keystore = "${KEYSTORE_PATH}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
export/android/shutdown_adb_on_exit = true
EOF

echo "Generated ~/.config/godot/editor_settings-4.tres:"
cat ~/.config/godot/editor_settings-4.tres
echo "=== Done ==="
