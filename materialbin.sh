#!/bin/sh

# Script to download libmaterialbinloader.so and place it in the appropriate MCPE mods directory
# Compatible with both Trinity Launcher (Flatpak) and standard mcpelauncher installations

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

# Function to check if a directory exists, create if it doesn't
ensure_directory_exists() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        print_info "Directory $dir does not exist. Creating it..."
        mkdir -p "$dir"
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create directory: $dir"
            return 1
        else
            print_info "Successfully created directory: $dir"
        fi
    else
        print_info "Directory already exists: $dir"
    fi
    
    return 0
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
    # If neither exists, ask user which one to use
    else
        print_info "No existing mcpelauncher directory found."
        
        # Prompt user to choose installation type
        echo "Please select installation type:"
        echo "1) Trinity Launcher (Flatpak)"
        echo "2) Standard mcpelauncher"
        echo "3) Exit"
        
        read -p "Enter choice (1-3): " choice
        
        case $choice in
            1)
                echo "$TRINITY_MODS_DIR"
                ;;
            2)
                echo "$STANDARD_MODS_DIR"
                ;;
            3)
                echo "exit"
                ;;
            *)
                print_error "Invalid choice. Exiting."
                echo "exit"
                ;;
        esac
    fi
}

# Function to download the file
download_file() {
    local url="$1"
    local output_dir="$2"
    local filename="libmaterialbinloader.so"
    local output_path="$output_dir/$filename"
    
    print_info "Downloading $filename from $url..."
    
    # Use curl if available
    if command -v curl &> /dev/null; then
        curl -L -o "$output_path" "$url"
        curl_exit_code=$?
        if [ $curl_exit_code -ne 0 ]; then
            print_error "curl failed with exit code $curl_exit_code"
            return 1
        fi
    # Fallback to wget if curl is not available
    elif command -v wget &> /dev/null; then
        wget -O "$output_path" "$url"
        wget_exit_code=$?
        if [ $wget_exit_code -ne 0 ]; then
            print_error "wget failed with exit code $wget_exit_code"
            return 1
        fi
    else
        print_error "Neither curl nor wget is available. Cannot download file."
        return 1
    fi
    
    # Check if download was successful
    if [ -f "$output_path" ]; then
        print_info "File successfully downloaded to: $output_path"
        
        # Set appropriate permissions (read and write for user, read for group and others)
        chmod 644 "$output_path"
        
        # Verify file is not empty
        file_size=$(stat -c%s "$output_path" 2>/dev/null || stat -f%z "$output_path" 2>/dev/null)
        if [ "$file_size" -eq 0 ]; then
            print_error "Downloaded file is empty. The download may have failed."
            return 1
        fi
        
        print_info "File size: $file_size bytes"
        return 0
    else
        print_error "Download failed. File not found at expected location."
        return 1
    fi
}

# Main script execution
main() {
    print_info "Starting Material Bin Loader installation script..."
    
    # Select the appropriate mods directory
    MODS_DIR=$(select_mods_directory)
    
    if [ "$MODS_DIR" = "exit" ]; then
        print_info "Exiting script as requested."
        exit 0
    fi
    
    print_info "Selected mods directory: $MODS_DIR"
    
    # Ensure the mods directory exists
    if ! ensure_directory_exists "$MODS_DIR"; then
        print_error "Failed to create or access mods directory. Exiting."
        exit 1
    fi
    
    # Download the file to the mods directory
    if download_file "$DOWNLOAD_URL" "$MODS_DIR"; then
        print_info "Installation completed successfully."
        print_info "File placed in: $MODS_DIR/libmaterialbinloader.so"
    else
        print_error "Installation failed. Please check the error messages above."
        exit 1
    fi
}

# Run the main function
main
