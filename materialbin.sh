#!/bin/bash

# Simple script to download libmaterialbinloader.so to MCPE mods directory

# URL to download
URL="https://github.com/franckey02/mcpe-materialbinloader/raw/refs/heads/main/libmaterialbinloader.so"

# Try Trinity Launcher directory first, then standard directory
if [ -d "$HOME/.var/app/com.trench.trinity.launcher" ]; then
    MODS_DIR="$HOME/.var/app/com.trench.trinity.launcher/data/mcpelauncher/mods"
    echo "Using Trinity Launcher directory"
else
    MODS_DIR="$HOME/.local/share/mcpelauncher/mods"
    echo "Using standard mcpelauncher directory"
fi

# Create mods directory if it doesn't exist
echo "Creating mods directory: $MODS_DIR"
mkdir -p "$MODS_DIR"

# Full path to target file
TARGET_FILE="$MODS_DIR/libmaterialbinloader.so"

# Download the file
echo "Downloading file..."
if command -v wget > /dev/null; then
    wget -q -O "$TARGET_FILE" "$URL"
elif command -v curl > /dev/null; then
    curl -s -L -o "$TARGET_FILE" "$URL"
else
    echo "Error: Need wget or curl to download file"
    exit 1
fi

# Check if download was successful
if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then
    echo "Success: File downloaded to $TARGET_FILE"
    echo "File size: $(du -h "$TARGET_FILE" | cut -f1)"
    echo ""
    echo "Contents of mods directory:"
    ls -la "$MODS_DIR/"
else
    echo "Error: Download failed or file is empty"
    exit 1
fi
