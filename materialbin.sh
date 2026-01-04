#!/bin/sh

# Script to download libmaterialbinloader.so and place it in the appropriate MCPE mods directory
# Fixed version - removes debug info from directory paths

# URL of the library file
DOWNLOAD_URL="https://github.com/franckey02/mcpe-materialbinloader/raw/refs/heads/main/libmaterialbinloader.so"

# Define possible mods directory paths
TRINITY_MODS_DIR="$HOME/.var/app/com.trench.trinity.launcher/data/mcpelauncher/mods"
STANDARD_MODS_DIR="$HOME/.local/share/mcpelauncher/mods"

# Function to display error messages
print_error() {
    echo "Error: $1" >&2
}

# Function to display informational messages
print_info() {
    echo "Info: $1"
}

# Function to display success messages
print_success() {
    echo "Success: $1"
}

# Function to determine which mods directory to use
select_mods_directory() {
    # Check for Trinity Launcher directory first (Flatpak installation)
    if [ -d "$HOME/.var/app/com.trench.trinity.launcher" ]; then
        print_info "Trinity Launcher (Flatpak) installation detected."
        echo "$TRINITY_MODS_DIR"
        return 0
    # Check for standard mcpelauncher directory
    elif [ -d "$HOME/.local/share/mcpelauncher" ]; then
        print_info "Standard mcpelauncher installation detected."
        echo "$STANDARD_MODS_DIR"
        return 0
    # If neither exists, use Trinity as default
    else
        print_info "No existing installation detected. Using Trinity Launcher path."
        echo "$TRINITY_MODS_DIR"
        return 0
    fi
}

# Function to ensure directory exists
ensure_directory_exists() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        print_info "Directory does not exist. Creating: $dir"
        mkdir -p "$dir"
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create directory: $dir"
            return 1
        else
            print_info "Directory created: $dir"
            return 0
        fi
    else
        print_info "Directory already exists: $dir"
        return 0
    fi
}

# Function to download file
download_file() {
    local url="$1"
    local output_path="$2"
    
    print_info "Downloading from: $url"
    
    # Use curl if available
    if command -v curl &> /dev/null; then
        curl -L -o "$output_path" "$url"
        if [ $? -ne 0 ]; then
            print_error "Download failed with curl"
            return 1
        fi
    # Fallback to wget
    elif command -v wget &> /dev/null; then
        wget -O "$output_path" "$url"
        if [ $? -ne 0 ]; then
            print_error "Download failed with wget"
            return 1
        fi
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi
    
    # Check if file was downloaded
    if [ -f "$output_path" ] && [ -s "$output_path" ]; then
        file_size=$(stat -c%s "$output_path" 2>/dev/null || stat -f%z "$output_path" 2>/dev/null)
        print_info "Download successful. File size: $file_size bytes"
        return 0
    else
        print_error "Downloaded file is empty or missing"
        return 1
    fi
}

# Function to verify installation
verify_installation() {
    local target_file="$1"
    
    if [ -f "$target_file" ]; then
        file_size=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null)
        print_success "File installed successfully: $target_file"
        print_info "Installed file size: $file_size bytes"
        return 0
    else
        print_error "File NOT found at: $target_file"
        return 1
    fi
}

# Main script
main() {
    print_info "Starting installation of Material Bin Loader..."
    echo "=============================================="
    
    # Get mods directory
    MODS_DIR=$(select_mods_directory)
    
    # Clean the MODS_DIR variable - remove any extra text
    MODS_DIR=$(echo "$MODS_DIR" | tr -d '\n' | sed 's/Info:.*detected\.//g' | xargs)
    
    print_info "Clean mods directory path: $MODS_DIR"
    
    # Ensure directory exists
    if ! ensure_directory_exists "$MODS_DIR"; then
        print_error "Cannot create mods directory. Exiting."
        exit 1
    fi
    
    # Define target file path
    TARGET_FILE="$MODS_DIR/libmaterialbinloader.so"
    
    print_info "Target file: $TARGET_FILE"
    
    # Download directly to target
    if ! download_file "$DOWNLOAD_URL" "$TARGET_FILE"; then
        print_error "Failed to download file"
        exit 1
    fi
    
    # Verify installation
    echo "=============================================="
    if verify_installation "$TARGET_FILE"; then
        print_success "Installation completed!"
        echo ""
        echo "Summary:"
        echo "  File: libmaterialbinloader.so"
        echo "  Location: $MODS_DIR"
        echo ""
        echo "Contents of mods directory:"
        ls -la "$MODS_DIR/"
    else
        print_error "Installation failed"
        
        # Show what's in the directory
        echo ""
        echo "Current contents of mods directory:"
        ls -la "$MODS_DIR/" 2>/dev/null || echo "Cannot list directory"
    fi
}

# Run main function
main
