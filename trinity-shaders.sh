#!/bin/sh

# Try default path first
default_mcpelauncher_root="$HOME/.local/share/mcpelauncher"
alternative_mcpelauncher_root="$HOME/.var/app/com.trench.trinity.launcher/data/mcpelauncher"

# Detect which path exists
if [ -d "$default_mcpelauncher_root" ]; then
    mcpelauncher_root="$default_mcpelauncher_root"
    echo "[*] Using default path: $default_mcpelauncher_root"
elif [ -d "$alternative_mcpelauncher_root" ]; then
    mcpelauncher_root="$alternative_mcpelauncher_root"
    echo "[*] Using alternative path: $alternative_mcpelauncher_root"
else
    echo "[!] mcpelauncher not found in any known location"
    echo "    Searched in:"
    echo "    - $default_mcpelauncher_root"
    echo "    - $alternative_mcpelauncher_root"
    echo
    exit 1
fi

# [!] Optionally, set your own data path (the com.mojang folder)
mcpelauncher_data="$mcpelauncher_root"/games/com.mojang

echo

if ! type "jq" &>/dev/null; then
    echo [!] jq not found. Please install it and add to PATH.
    echo
    exit 1
fi

if [ ! -f "$mcpelauncher_data/minecraftpe/global_resource_packs.json" ]; then
    echo [!] global_resource_packs.json not found.
    echo
    exit 1
fi

# Cache pack UUIDs and paths
declare -A pack_info
counter=1
echo [*] Getting resource pack list...
echo
for dir in "$mcpelauncher_data/resource_packs"/* ; do
    [ -d "$dir" ] || continue
    if [ -f "$dir/manifest.json" ]; then
        pack_uuid=$(jq -r '.header.uuid // empty' "$dir/manifest.json" 2>/dev/null)
        if [ -n "$pack_uuid" ]; then
            pack_version=$(jq -cr ".header.version | join(\".\")" "$dir/manifest.json" | sed 's/\.//g')
            pack_info["${pack_uuid}_${pack_version}"]="$dir"
            pack_name=$(jq -r '.header.name // empty' "$dir/manifest.json" 2>/dev/null)
            echo -e "$counter.\t$pack_name" | sed "s/§[a-zA-Z0-9]//g"
            ((counter++))
        else
            echo
            echo "[!] Skipping: $dir/manifest.json (UUID missing or invalid.)" | sed "s|$mcpelauncher_data/||"
            echo
        fi
    else
        for subdir in "$dir"/* ; do
            [ -d "$subdir" ] || continue
            if [ -f "$subdir/manifest.json" ]; then
                pack_uuid=$(jq -r '.header.uuid // empty' "$subdir/manifest.json" 2>/dev/null)
                if [ -n "$pack_uuid" ]; then
                    pack_version=$(jq -cr ".header.version | join(\".\")" "$subdir/manifest.json" | sed 's/\.//g')
                    pack_info["${pack_uuid}_${pack_version}"]="$subdir"
                    pack_name=$(jq -r '.header.name // empty' "$subdir/manifest.json" 2>/dev/null)
                    echo -e "$counter.\t$pack_name" | sed "s/§[a-zA-Z0-9]//g"
                    ((counter++))
                else
                    echo
                    echo "[!] Skipping: $dir/manifest.json (UUID missing or invalid)"
                    echo
                fi
            fi
        done
    fi
done

for dir in "$mcpelauncher_data/development_resource_packs"/* ; do
    [ -d "$dir" ] || continue
    if [ -f "$dir/manifest.json" ]; then
        pack_uuid=$(jq -r '.header.uuid // empty' "$dir/manifest.json" 2>/dev/null)
        if [ -n "$pack_uuid" ]; then
            pack_version=$(jq -cr ".header.version | join(\".\")" "$dir/manifest.json" | sed 's/\.//g')
            pack_info["${pack_uuid}_${pack_version}"]="$dir"
            pack_name=$(jq -r '.header.name // empty' "$dir/manifest.json" 2>/dev/null)
            echo -e "$counter.\t$pack_name [DEVELOPMENT]" | sed "s/§[a-zA-Z0-9]//g"
            ((counter++))
        else
            echo
            echo "[!] Skipping: $dir/manifest.json (UUID missing or invalid.)" | sed "s|$mcpelauncher_data/||"
            echo
        fi
    else
        for subdir in "$dir"/* ; do
            [ -d "$subdir" ] || continue
            if [ -f "$subdir/manifest.json" ]; then
                pack_uuid=$(jq -r '.header.uuid // empty' "$subdir/manifest.json" 2>/dev/null)
                if [ -n "$pack_uuid" ]; then
                    pack_version=$(jq -cr ".header.version | join(\".\")" "$subdir/manifest.json" | sed 's/\.//g')
                    pack_info["${pack_uuid}_${pack_version}"]="$subdir"
                    pack_name=$(jq -r '.header.name // empty' "$subdir/manifest.json" 2>/dev/null)
                    echo -e "$counter.\t$pack_name [DEVELOPMENT]" | sed "s/§[a-zA-Z0-9]//g"
                    ((counter++))
                else
                    echo
                    echo "[!] Skipping: $dir/manifest.json (UUID missing or invalid)"
                    echo
                fi
            fi
        done
    fi
done

echo
echo "[*] Found $((--counter)) packs"

first_pack_id=$(jq -r '.[0].pack_id' "$mcpelauncher_data/minecraftpe/global_resource_packs.json" 2>/dev/null)
pack_version=$(jq -cr ".[0].version | join(\".\")" "$mcpelauncher_data/minecraftpe/global_resource_packs.json")
subpack_name=$(jq -r '.[0].subpack // empty' "$mcpelauncher_data/minecraftpe/global_resource_packs.json")

echo
echo

for uuid in "${!pack_info[@]}"; do
    if [[ "${uuid,,}" == "${first_pack_id,,}_$(echo "${pack_version,,}" | sed 's/\.//g')" ]]; then
        first_pack_name=$(jq -r '.header.name' "${pack_info[$uuid]}/manifest.json" 2>/dev/null)
        
        pack_path=${pack_info[$uuid]}
        echo -e "First global pack name: $first_pack_name v$pack_version ($first_pack_id)" | sed "s/§[a-zA-Z0-9]//g"
        echo -e "Pack path: \t\t$pack_path" | sed "s|$mcpelauncher_data/||"

        if [ -n "$subpack_name" ]; then
            echo -e "hasSubpack:\t\ttrue"
            echo -e "Subpack path: \t\t$pack_path/subpacks/$subpack_name" | sed "s|$mcpelauncher_data/||"
        else
            echo -e hasSubpack:\t\tfalse
        fi

        break
    fi
done

echo
echo

if [ ! -d "$mcpelauncher_root/shaders" ]; then
    echo "[!] shaders folder not found. Please create it yourself."
    echo "    mkdir -p \"$mcpelauncher_root/shaders\""
    echo
    exit 1
fi

if ls "$pack_path/renderer/materials/"*.material.bin &>/dev/null; then
    :
elif [ -n "$subpack_name" ] && ls "$pack_path/subpacks/$subpack_name/renderer/materials/"*.material.bin &>/dev/null; then
    :
else
    echo "[!] No .material.bin files found in the pack."
    echo
    echo "[*] Emptying shaders folder..."
    echo
    rm -rf "$mcpelauncher_root/shaders"/*
    exit 0
fi

rm -rf "$mcpelauncher_root/shaders"/*
ln -sf "$pack_path/renderer/materials/"*.material.bin "$mcpelauncher_root/shaders"/
if [ -n "$subpack_name" ]; then
    if ls "$pack_path/subpacks/$subpack_name/renderer/materials/"*.material.bin &>/dev/null; then
        ln -sf "$pack_path/subpacks/$subpack_name/renderer/materials/"*.material.bin "$mcpelauncher_root/shaders"/
    fi
fi

echo "[*] Symlinks to materials created in $(echo $mcpelauncher_root/shaders | sed "s|$HOME|\$HOME|")"
echo
echo Have good day!

echo
